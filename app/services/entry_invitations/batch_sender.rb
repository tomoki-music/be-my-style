module EntryInvitations
  # 複数の「曲 × パート × 経験者」をまとめて処理する。
  #
  # 曲 × パート単位にグループ化(TargetResolver)し、グループごとに既存の
  # EntryInvitations::Sender へ委譲する。Sender 側の
  #   - 送信者権限チェック / 経験者の再検証 / 24時間以内の再送防止
  #   - DB ユニーク制約・RecordNotUnique 対応 / Job enqueue / Mailer / メール件名・本文
  #   - 1 曲・1 パート単位の通知
  # は一切変更しない。メール・通知は従来どおり曲・パート単位で送られる
  # (同じユーザーへ別の曲・パートを依頼した場合は複数メールになることを許容)。
  #
  # 複数グループを 1 つの DB トランザクションにはまとめない。あるグループの送信が
  # 失敗しても、既に成功したグループの依頼は取り消さない・二重送信しない。
  class BatchSender
    Result = Struct.new(:queued_count, :recently_sent_count, :skipped_count, :error, keyword_init: true) do
      def success?
        error.nil?
      end

      def queued?
        queued_count.to_i.positive?
      end
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(event:, sender:, raw_targets:, now: Time.current)
      @event = event
      @sender = sender
      @raw_targets = raw_targets
      @now = now
    end

    def call
      global_error = validate_global
      return failure(global_error) if global_error

      groups = TargetResolver.call(event: @event, raw_targets: @raw_targets, now: @now)
      return failure("送信できる対象者がいませんでした。選び直してください。") if groups.empty?

      queued = 0
      recently_sent = 0
      skipped = requested_count - groups.sum { |group| group.customers.size }

      groups.each do |group|
        result = EntryInvitations::Sender.call(
          event: @event,
          song: group.song,
          join_part: group.join_part,
          sender: @sender,
          requested_customer_ids: group.customer_ids,
          now: @now
        )

        unless result.success?
          # グループ単位で送信不可(募集が締め切られた等)。既存成功分はそのまま。
          skipped += group.customers.size
          next
        end

        queued += result.queued_count
        result.skipped.each do |entry|
          if entry[:reason] == :recently_sent
            recently_sent += 1
          else
            skipped += 1
          end
        end
      end

      Result.new(
        queued_count: queued,
        recently_sent_count: recently_sent,
        skipped_count: [skipped, 0].max,
        error: nil
      )
    end

    private

    def validate_global
      return "このイベントで送信する権限がありません。" unless @sender&.can_destroy_event?(@event)
      return "終了したイベントには送信できません。" if @event.ended?(now: @now)

      parsed = TargetParser.parse(@raw_targets)
      return "送信対象者が選択されていません。" if parsed.empty?
      return "一度に選択できるのは#{TargetParser::MAX_TARGETS}人までです。数を減らして選び直してください。" if parsed.size > TargetParser::MAX_TARGETS

      nil
    end

    def requested_count
      @requested_count ||= TargetParser.parse(@raw_targets).size
    end

    def failure(message)
      Result.new(queued_count: 0, recently_sent_count: 0, skipped_count: 0, error: message)
    end
  end
end
