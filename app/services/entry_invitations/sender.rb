module EntryInvitations
  # イベント楽曲の演奏経験者へ「エントリー依頼メール」を送る中心ロジック。
  #
  # Controller から渡された customer_id 群は一切信用せず、ここで
  #   - 送信者の権限(can_destroy_event?)
  #   - イベント/曲/パートが送信可能な状態か(未終了・所属整合。パートの募集状態は問わない)
  #   - 各 customer_id が「別の終了済みイベントに同一SongMaster・同一正規化パートの実績を持つ経験者」か
  #     (= PerformanceHistory::ExperiencedCustomersQuery の結果に含まれるか)
  #   - 受信者ごとの追加条件(退会でない・未エントリー・メール通知ON・メールあり・24h以内未送信)
  # をサーバー側で再計算する。
  #
  # 実送信は SendEntryInvitationJob(非同期)へ委譲し、受信者ごとに個別メールを送る。
  class Sender
    Result = Struct.new(:queued, :skipped, :error, keyword_init: true) do
      def queued_count
        queued.size
      end

      def success?
        error.nil?
      end
    end

    SKIP_REASON_LABELS = {
      not_experienced: "演奏経験者ではないため対象外",
      already_entered: "すでにこのパートへエントリー済み",
      mail_opt_out: "メール通知をオフにしている",
      no_email: "有効なメールアドレスがない",
      withdrawn: "退会済み",
      recently_sent: "24時間以内に送信済み(依頼済み)"
    }.freeze

    EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(event:, song:, join_part:, sender:, requested_customer_ids:, now: Time.current)
      @event = event
      @song = song
      @join_part = join_part
      @sender = sender
      @requested_customer_ids = Array(requested_customer_ids).map(&:to_i).uniq
      @now = now
    end

    def call
      authorization_error = validate_context
      return Result.new(queued: [], skipped: [], error: authorization_error) if authorization_error

      experienced_by_id = experienced_customers.index_by(&:id)
      queued = []
      skipped = []

      @requested_customer_ids.each do |customer_id|
        customer = experienced_by_id[customer_id]
        if customer.nil?
          skipped << { customer_id: customer_id, customer: nil, reason: :not_experienced }
          next
        end

        reason = disqualification_reason(customer)
        if reason
          skipped << { customer_id: customer_id, customer: customer, reason: reason }
          next
        end

        invitation = upsert_invitation(customer)
        if invitation
          queued << { customer: customer, invitation: invitation }
        else
          skipped << { customer_id: customer_id, customer: customer, reason: :recently_sent }
        end
      end

      enqueue_delivery(queued)

      Result.new(queued: queued.map { |q| q[:customer] }, skipped: skipped, error: nil)
    end

    private

    # 全件送信不可となる前提条件。問題なければ nil。
    def validate_context
      return "このイベントで送信する権限がありません。" unless @sender&.can_destroy_event?(@event)
      return "曲またはパートの指定が正しくありません。" unless @song && @join_part
      return "曲またはパートの指定が正しくありません。" unless @song.event_id == @event.id && @join_part.song_id == @song.id
      return "終了したイベントには送信できません。" if @event.ended?(now: @now)

      nil
    end

    # このイベント・この曲・このパートの「演奏経験のある人」。
    # ExperiencedCustomersQuery が SongMaster 一致・正規化パート一致・別の終了済みイベント・
    # is_deleted=false・Customer 現存 をまとめて満たす。
    def experienced_customers
      key = PerformanceHistory::ExperiencedCustomersQuery.key_for(@song.song_master_id, @join_part.join_part_name)
      return [] if key.nil?

      PerformanceHistory::ExperiencedCustomersQuery.call(@event, now: @now).fetch(key, [])
    end

    def disqualification_reason(customer)
      return :withdrawn if customer.is_deleted?
      return :no_email if customer.email.blank? || !customer.email.match?(EMAIL_FORMAT)
      return :mail_opt_out unless customer.confirm_mail
      return :already_entered if already_entered?(customer)

      existing = existing_invitation_for(customer)
      return :recently_sent if existing&.within_resend_window?(now: @now)

      nil
    end

    def already_entered?(customer)
      JoinPartCustomer.exists?(join_part_id: @join_part.id, customer_id: customer.id)
    end

    def existing_invitations_by_customer_id
      @existing_invitations_by_customer_id ||=
        EntryInvitation
          .where(event_id: @event.id, song_id: @song.id, join_part_id: @join_part.id)
          .index_by(&:customer_id)
    end

    def existing_invitation_for(customer)
      existing_invitations_by_customer_id[customer.id]
    end

    # (event, song, join_part, customer) につき常に1行。再送可能なら sent_at を更新する。
    # 並行 INSERT による UNIQUE 制約違反は「直近に他リクエストが送信済み」とみなし nil を返す。
    def upsert_invitation(customer)
      invitation = EntryInvitation.find_or_initialize_by(
        event_id: @event.id, song_id: @song.id, join_part_id: @join_part.id, customer_id: customer.id
      )
      return nil if invitation.persisted? && invitation.within_resend_window?(now: @now)

      invitation.assign_attributes(
        requested_by_customer: @sender,
        sent_at: @now,
        failure_reason: nil,
        status: delivery_allowed? ? :pending : :skipped
      )
      invitation.failure_reason = "非本番環境のため送信をスキップしました" unless delivery_allowed?
      invitation.save!
      invitation
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def enqueue_delivery(queued)
      return unless delivery_allowed?

      queued.each do |entry|
        SendEntryInvitationJob.perform_later(entry[:invitation].id)
      end
    end

    # 開発環境は実際の Gmail SMTP 設定のため、実在ユーザーへの誤送信を防ぐ。
    # test 環境は delivery_method=:test で実送信されないため許可する。
    def delivery_allowed?
      return @delivery_allowed if defined?(@delivery_allowed)

      @delivery_allowed =
        Rails.env.production? ||
        Rails.env.test? ||
        ENV["ENTRY_INVITATION_ALLOW_REAL_EMAILS"].to_s.strip.length.positive?
    end
  end
end
