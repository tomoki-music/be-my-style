module SongPerformances
  # 終了済みイベントのJoinPartCustomer(実際のパートエントリー)を、演奏実績(SongPerformance)へ
  # 反映するサービスオブジェクト。
  #
  # 「開催前イベントへのエントリーはまだ確定した演奏実績として扱わない」ため、対象イベントが
  # 終了済み(Event#ended?)でない場合は何もしない。呼び出し元は次の2箇所に限定し、
  # 「画面を閲覧しただけで偶然登録される」実装は採用しない。
  #   - 主催者/管理者が明示的に押す「演奏実績を確定」アクション(Public::EventsController#sync_performances)
  #   - 過去データ用のrake song_performances:backfill
  #
  # 退会済み(is_deleted)customerや、エントリー取消済み(JoinPartCustomer自体が存在しない)分は
  # 対象に含まれない(existingスコープを見ているだけなので、取消済みは元々候補に上がらない)。
  # 何度実行しても重複しない(SongPerformance側のUNIQUE制約 + find_or_initialize_byで冪等)。
  class EventSync
    Result = Struct.new(:target, :created, :skipped, keyword_init: true)

    def self.call(event, dry_run: false)
      new(event, dry_run: dry_run).call
    end

    def initialize(event, dry_run: false)
      @event = event
      @dry_run = dry_run
    end

    def call
      target = 0
      created = 0
      skipped = 0

      return Result.new(target: 0, created: 0, skipped: 0) unless @event.ended?

      @event.songs.includes(join_parts: { join_part_customers: :customer }).find_each do |song|
        song_master = resolve_song_master(song)
        next if song_master.blank?

        song.join_parts.each do |join_part|
          join_part.join_part_customers.each do |join_part_customer|
            customer = join_part_customer.customer
            next if customer.blank? || customer.is_deleted?

            target += 1

            if already_synced?(customer, song_master, join_part)
              skipped += 1
              next
            end

            if @dry_run
              # dry-runでは実際には作成せず、「登録予定件数」としてのみ数える。
              created += 1
              next
            end

            if create_performance!(customer, song_master, song, join_part)
              created += 1
            else
              skipped += 1
            end
          end
        end
      end

      Result.new(target: target, created: created, skipped: skipped)
    end

    private

    def resolve_song_master(song)
      return song.song_master if song.song_master_id.present?

      SongMasters::Resolver.call(song_name: song.song_name, artist_name: song.artist_name)
    end

    def already_synced?(customer, song_master, join_part)
      SongPerformance.exists?(
        customer_id: customer.id,
        song_master_id: song_master.id,
        part_name: join_part.join_part_name,
        event_id: @event.id
      )
    end

    def create_performance!(customer, song_master, song, join_part)
      SongPerformance.create(
        customer_id: customer.id,
        song_master_id: song_master.id,
        song_id: song.id,
        event_id: @event.id,
        join_part_id: join_part.id,
        part_name: join_part.join_part_name,
        performed_on: @event.event_start_time&.to_date
      ).persisted?
    end
  end
end
