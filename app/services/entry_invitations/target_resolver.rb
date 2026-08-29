module EntryInvitations
  # パース済み targets を「イベント・曲・パート・演奏経験者」の観点でサーバー側再検証し、
  # 曲 × パート単位にグループ化する。確認画面(new)の表示と hidden field 生成、
  # および BatchSender のグループ化に使う。
  #
  # 検証内容(送信者の権限・イベント終了判定は呼び出し側で担保):
  #   1. Song が対象 Event に所属している
  #   2. JoinPart が対象 Song に所属している
  #   3. Customer が存在する(退会者は ExperiencedCustomersQuery が除外済み)
  #   4. Customer がその曲・パートの演奏経験者(別の終了済みイベントに実績あり)
  #
  # パートの募集状態(recruiting_join_parts)は検証しない。募集終了パートでも経験者へは
  # 依頼でき、受信者は通常のエントリー導線からそのパートへ参加できる。
  #
  # 24時間以内の再送防止は送信時に EntryInvitations::Sender が再判定するため、ここでは扱わない
  # (確認画面には「依頼済み」バッジ付きで表示し、実送信でスキップする既存 UX を踏襲)。
  class TargetResolver
    Group = Struct.new(:song, :join_part, :customers, keyword_init: true) do
      # hidden field / 再送信用の "song_id:join_part_id:customer_id" トークン列。
      def target_tokens
        customers.map { |customer| "#{song.id}:#{join_part.id}:#{customer.id}" }
      end

      def customer_ids
        customers.map(&:id)
      end
    end

    def self.call(event:, raw_targets:, now: Time.current)
      new(event: event, raw_targets: raw_targets, now: now).call
    end

    def initialize(event:, raw_targets:, now: Time.current)
      @event = event
      @triples = TargetParser.parse(raw_targets)
      @now = now
    end

    # 戻り値: [Group, ...](有効な曲 × パートのみ・customers も検証済みのみ・順序は曲/パートの登場順)
    def call
      return [] if @triples.empty?
      return [] if @event.ended?(now: @now)

      experienced_by_key = PerformanceHistory::ExperiencedCustomersQuery.call(@event, now: @now)

      grouped = @triples.group_by { |song_id, join_part_id, _customer_id| [song_id, join_part_id] }

      grouped.filter_map do |(song_id, join_part_id), triples|
        song = songs_by_id[song_id]
        next unless song

        join_part = song.join_parts.detect { |part| part.id == join_part_id }
        next unless join_part

        key = PerformanceHistory::ExperiencedCustomersQuery.key_for(song.song_master_id, join_part.join_part_name)
        next if key.nil?

        experienced_by_id = experienced_by_key.fetch(key, []).index_by(&:id)
        customers = triples.filter_map { |_song_id, _join_part_id, customer_id| experienced_by_id[customer_id] }
        next if customers.empty?

        Group.new(song: song, join_part: join_part, customers: customers)
      end
    end

    private

    def songs_by_id
      @songs_by_id ||= @event.songs.index_by(&:id)
    end
  end
end
