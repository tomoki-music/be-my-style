module SongMasters
  # 既存SongをSongMasterへ(再)紐付けし、その結果として参照が無くなったSongMasterを整理する。
  #
  # SongMasters::Resolverの解決ロジック改善(例: 「曲名（アーティスト名）」形式の分解)により、
  # 過去に別々のSongMasterへ分かれて登録されたSongを、現在の正しいSongMasterへ寄せ直す必要がある。
  # 画面表示時のQuery Objectは読み取り専用のため、この整理は冪等なバックフィルに閉じる。
  #
  # 安全設計:
  # - dry_run: true の場合、DBを一切変更しない(SongMasterのfind_or_createも行わず、
  #   既存SongMasterの検索のみ)。実行予定の内容だけを組み立てて返す。
  # - 通常実行は単一トランザクション内で「再リンク → 孤立SongMaster削除」の順に行う。
  #   途中で例外が発生すれば全体がロールバックされ、中途半端な状態を残さない。
  # - 孤立SongMasterの削除は再リンク完了後にのみ実施し、かつ削除直前に
  #   「参照Songが0件」「customer_song_partsから参照されていない」ことを再確認する。
  # - SongMasterの解決自体はResolverに委譲するため、意味的に異なる曲を統合することはない。
  # - song_master_idが既に正しいSongはスキップするため、何度実行しても結果は変わらない。
  class BackfillSongs
    RelinkPlan = Struct.new(
      :song_id, :song_name, :artist_name, :from_song_master_id, :to_song_master_id, :to_new_master_key,
      keyword_init: true
    )
    CreatePlan = Struct.new(
      :normalized_song_name, :normalized_artist_name, :song_name, :artist_name, :song_ids,
      keyword_init: true
    )
    OrphanPlan = Struct.new(
      :song_master_id, :song_name, :artist_name, :current_referencing_song_count,
      keyword_init: true
    )
    SkippedSong = Struct.new(:song_id, :song_name, :artist_name, keyword_init: true)

    Result = Struct.new(
      :dry_run, :relinks, :creates, :orphans, :skipped,
      :songs_before, :songs_after, :song_masters_before, :song_masters_after, :deleted_song_master_ids,
      keyword_init: true
    ) do
      def relink_count
        relinks.size
      end
    end

    def self.call(dry_run:, logger: ->(_message) {})
      new(dry_run: dry_run, logger: logger).call
    end

    def initialize(dry_run:, logger:)
      @dry_run = dry_run
      @logger = logger
    end

    def call
      songs_before = Song.count
      song_masters_before = SongMaster.count

      analyze
      report_plan

      deleted_song_master_ids = []
      unless @dry_run
        ActiveRecord::Base.transaction do
          relink_songs!
          deleted_song_master_ids = delete_orphan_song_masters!
        end
      end

      result = Result.new(
        dry_run: @dry_run,
        relinks: @relinks,
        creates: @creates.values,
        orphans: @orphans,
        skipped: @skipped,
        songs_before: songs_before,
        songs_after: Song.count,
        song_masters_before: song_masters_before,
        song_masters_after: SongMaster.count,
        deleted_song_master_ids: deleted_song_master_ids
      )
      report_result(result)
      result
    end

    private

    # DBを変更せず、再リンク・新規作成・孤立削除の予定を組み立てる。
    def analyze
      @relinks = []
      @skipped = []
      @creates = {} # [nsn, nan] => CreatePlan
      # song_id => 再リンク後に参照する既存SongMaster id。新規作成予定マスターへ寄せる場合はnil。
      # スキップ・現状維持のSongはキー自体を持たない。
      @planned_master_id = {}

      Song.includes(:song_master).find_each do |song|
        identity = SongMasters::Resolver.identity_for(song_name: song.song_name, artist_name: song.artist_name)
        if identity.nil?
          @skipped << SkippedSong.new(song_id: song.id, song_name: song.song_name, artist_name: song.artist_name)
          next
        end

        existing = SongMaster.find_by(
          normalized_song_name: identity.normalized_song_name,
          normalized_artist_name: identity.normalized_artist_name
        )

        if existing
          @planned_master_id[song.id] = existing.id
          next if existing.id == song.song_master_id

          @relinks << RelinkPlan.new(
            song_id: song.id,
            song_name: song.song_name,
            artist_name: song.artist_name,
            from_song_master_id: song.song_master_id,
            to_song_master_id: existing.id,
            to_new_master_key: nil
          )
        else
          key = [identity.normalized_song_name, identity.normalized_artist_name]
          plan = (@creates[key] ||= CreatePlan.new(
            normalized_song_name: identity.normalized_song_name,
            normalized_artist_name: identity.normalized_artist_name,
            song_name: identity.song_name,
            artist_name: identity.artist_name,
            song_ids: []
          ))
          plan.song_ids << song.id
          @planned_master_id[song.id] = nil
          @relinks << RelinkPlan.new(
            song_id: song.id,
            song_name: song.song_name,
            artist_name: song.artist_name,
            from_song_master_id: song.song_master_id,
            to_song_master_id: nil,
            to_new_master_key: key
          )
        end
      end

      @orphans = projected_orphans
    end

    # 再リンク適用後に「参照Songが0件」かつ「customer_song_partsから参照されない」SongMasterを予測する。
    def projected_orphans
      post_song_counts = Hash.new(0)
      Song.pluck(:id, :song_master_id).each do |song_id, current_master_id|
        target =
          if @planned_master_id.key?(song_id)
            @planned_master_id[song_id] # 既存id or nil(新規作成予定マスターへ寄せる)
          else
            current_master_id # スキップ・現状維持
          end
        post_song_counts[target] += 1 if target
      end

      referenced_by_csp = CustomerSongPart.distinct.pluck(:song_master_id).to_set

      SongMaster.order(:id).filter_map do |master|
        next if referenced_by_csp.include?(master.id)
        next unless post_song_counts[master.id].zero?

        OrphanPlan.new(
          song_master_id: master.id,
          song_name: master.song_name,
          artist_name: master.artist_name,
          current_referencing_song_count: master.songs.count
        )
      end
    end

    # トランザクション内で呼ばれる。Resolver.callで正しいSongMasterを取得(必要なら作成)し、
    # song_master_idが変わるSongだけをupdate_columnで更新する(assign_song_masterコールバックは意図的に回避)。
    def relink_songs!
      Song.includes(:song_master).find_each do |song|
        master = SongMasters::Resolver.call(song_name: song.song_name, artist_name: song.artist_name)
        next if master.nil?
        next if master.id == song.song_master_id

        song.update_column(:song_master_id, master.id)
      end
    end

    # 再リンク完了後にのみ呼ばれる。削除直前に参照が無いことを再確認してから物理削除する。
    def delete_orphan_song_masters!
      candidate_ids = SongMaster
        .where.not(id: Song.where.not(song_master_id: nil).select(:song_master_id))
        .where.not(id: CustomerSongPart.select(:song_master_id))
        .pluck(:id)
      return [] if candidate_ids.empty?

      # 念のため、削除対象になった後に別トランザクションから参照が付いていないか最終確認する。
      still_referenced =
        Song.where(song_master_id: candidate_ids).distinct.pluck(:song_master_id) |
        CustomerSongPart.where(song_master_id: candidate_ids).distinct.pluck(:song_master_id)
      deletable_ids = candidate_ids - still_referenced
      return [] if deletable_ids.empty?

      SongMaster.where(id: deletable_ids).delete_all
      deletable_ids
    end

    def report_plan
      log("== 実行予定(read-only) ==")
      log("再リンク予定のSong: #{@relinks.size}件")
      @relinks.each do |plan|
        to = plan.to_song_master_id ? "SongMaster##{plan.to_song_master_id}" : "新規SongMaster(#{plan.to_new_master_key.inspect})"
        log("  Song##{plan.song_id} #{plan.song_name.inspect} / #{plan.artist_name.inspect}: " \
            "#{plan.from_song_master_id.inspect} -> #{to}")
      end

      log("新規作成予定のSongMaster: #{@creates.size}件")
      @creates.each_value do |plan|
        log("  song_name=#{plan.song_name.inspect} artist_name=#{plan.artist_name.inspect} " \
            "(normalized=#{plan.normalized_song_name.inspect}/#{plan.normalized_artist_name.inspect}) " \
            "対象Song##{plan.song_ids.join(',')}")
      end

      log("孤立して削除候補となるSongMaster: #{@orphans.size}件")
      @orphans.each do |plan|
        log("  SongMaster##{plan.song_master_id} song_name=#{plan.song_name.inspect} " \
            "artist_name=#{plan.artist_name.inspect} 現在の参照Song数=#{plan.current_referencing_song_count}件" \
            "(再リンク後は0件になる見込み)")
      end

      log("曖昧・解決不可のため処理しないSong: #{@skipped.size}件")
      @skipped.each do |skipped|
        log("  Song##{skipped.song_id} #{skipped.song_name.inspect} / #{skipped.artist_name.inspect}")
      end
    end

    def report_result(result)
      if result.dry_run
        log("== DRY RUN のため DB は変更していません ==")
      else
        log("== 実行結果 ==")
        log("再リンクしたSong: #{result.relink_count}件(予定ベース)")
        log("削除したSongMaster: #{result.deleted_song_master_ids.size}件 #{result.deleted_song_master_ids.inspect}")
      end
      log("Song件数: #{result.songs_before} -> #{result.songs_after}")
      log("SongMaster件数: #{result.song_masters_before} -> #{result.song_masters_after}")
      log("完了しました")
    end

    def log(message)
      @logger.call(message)
    end
  end
end
