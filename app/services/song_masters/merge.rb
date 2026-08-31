module SongMasters
  # 「本来同一の楽曲なのに別SongMasterへ分裂している」2件を、片方(正)へ安全に統合する。
  #
  # 背景:
  #   SongMasters::Resolver.normalize は意味的な表記ゆれ(「曲名／アーティスト」併記、引用符・
  #   括弧・区切り文字のゆれ等)を、誤統合防止のためあえて吸収しない。そのため本来同一の楽曲でも
  #   別SongMasterへ分裂することがある。単純に統合元SongMasterを削除するだけだと、同じ旧表記の
  #   Songが再保存されたときにSongMasterが再作成され、再び分裂する。
  #
  # 恒久対応:
  #   統合元SongMasterの正規化キーを SongMasterAlias として正SongMasterへ向ける。Resolver は
  #   通常の完全一致で解決できなかったときにこのエイリアスを引くため、旧表記のSongが再保存されても
  #   分裂SongMasterは再作成されない。
  #
  # 安全設計:
  #   - dry_run: true では DB を一切変更しない。参照のみで統合予定(移動対象数・UNIQUE衝突・
  #     作成予定エイリアス・未知参照の有無・実行可否)を組み立てて返す。ロールバック前提の疑似更新は
  #     行わない。
  #   - 本適用は1組の統合を単一トランザクションで行う。正・統合元SongMasterを行ロックし、
  #     既知参照(songs / customer_song_parts / song_master_aliases)を正へ付け替え、CustomerSongPart の
  #     UNIQUE(customer_id, song_master_id, part_name)衝突を安全にデデュープしてから統合元を削除する。
  #   - 統合元を削除する直前に「既知参照が0件」「song_masters を参照する未知の外部キーが無い」ことを
  #     再確認する。未知参照があれば削除せずロールバックする。
  #   - 意味的に異なる楽曲まで自動統合しない。統合対象は呼び出し元(rake タスク)が明示的に渡した
  #     ID ペアだけ。
  #   - 統合元SongMasterが存在しない場合(canonical のみ実在)は「既に統合済み」と決めつけず中止する。
  #     旧merge_idがこのkeep_idへ統合された恒久証跡を持たないため、ID誤り・想定外の削除を成功扱い
  #     しない(冪等性は「DBを二重更新しない」ことで担保する)。
  #   - 統合元の正規化キーが「別のSongMaster」へ解決する SongMasterAlias に既に使われている場合は、
  #     誤ったSongMasterへ寄せないよう中止する。
  #
  # 複数ペアをまとめて(全ペア単一トランザクションで)適用したい場合は SongMasters::MergeBatch を使う。
  # このサービス単体でも本適用は1組を1トランザクションで行うが、MergeBatch の外側トランザクション内で
  # 呼ばれた場合は(requires_new を使わないため)そのトランザクションに参加し、いずれかのペアで例外が
  # 出れば全ペアがロールバックされる。
  class Merge
    # song_masters.id を参照している「既知の(このサービスが付け替えを行う)」カラム。
    # information_schema から得た参照カラム集合との差分が「未知参照」。
    KNOWN_REFERENCING_COLUMNS = %w[
      songs.song_master_id
      customer_song_parts.song_master_id
      song_master_aliases.song_master_id
    ].freeze

    AliasPlan = Struct.new(:song_master_id, :normalized_song_name, :normalized_artist_name, keyword_init: true)

    # customer_song_part の UNIQUE(customer_id, song_master_id, part_name)衝突の内訳。
    ConflictPlan = Struct.new(
      :customer_id, :part_name, :canonical_customer_song_part_id, :duplicate_customer_song_part_id,
      :canonical_song_id, :duplicate_song_id, :resolvable,
      keyword_init: true
    )

    Result = Struct.new(
      :dry_run, :performed,
      :canonical_id, :duplicate_id, :canonical, :duplicate,
      :movable_song_count, :movable_customer_song_part_count, :conflicting_customer_song_part_count,
      :conflicts, :planned_alias, :existing_alias,
      :deletable_song_master_id, :unknown_references,
      :executable, :aborted_reason,
      :songs_moved, :customer_song_parts_moved, :customer_song_parts_deduped, :alias_created,
      keyword_init: true
    ) do
      def executable?
        executable
      end
    end

    def self.call(canonical_id:, duplicate_id:, dry_run:, logger: ->(_message) {})
      new(canonical_id: canonical_id, duplicate_id: duplicate_id, dry_run: dry_run, logger: logger).call
    end

    def initialize(canonical_id:, duplicate_id:, dry_run:, logger:)
      @canonical_id = canonical_id
      @duplicate_id = duplicate_id
      @dry_run = dry_run
      @logger = logger
    end

    def call
      @dry_run ? analyze : perform
    end

    private

    # DBを一切変更せず、統合予定と実行可否を組み立てて返す。
    def analyze
      canonical = SongMaster.find_by(id: @canonical_id)
      duplicate = SongMaster.find_by(id: @duplicate_id)

      plan = build_plan(canonical, duplicate)
      report_plan(plan)
      plan
    end

    # 1組の統合をトランザクション内で適用する。
    def perform
      result = nil

      ActiveRecord::Base.transaction do
        # デッドロック回避のため id 昇順で行ロックする。
        locked = SongMaster.lock.where(id: [@canonical_id, @duplicate_id].uniq).order(:id).index_by(&:id)
        canonical = locked[@canonical_id]
        duplicate = locked[@duplicate_id]

        plan = build_plan(canonical, duplicate)
        report_plan(plan)

        unless plan.executable?
          result = plan
          next
        end

        songs_moved = Song.where(song_master_id: duplicate.id).update_all(song_master_id: canonical.id)
        deduped = dedupe_conflicting_customer_song_parts!(canonical.id, duplicate.id)
        csp_moved = CustomerSongPart.where(song_master_id: duplicate.id).update_all(song_master_id: canonical.id)
        move_aliases_to_canonical!(canonical.id, duplicate.id)
        alias_record = upsert_legacy_key_alias!(canonical, duplicate)

        verify_no_known_references!(duplicate.id)
        verify_no_unknown_references!

        SongMaster.where(id: duplicate.id).delete_all

        verify_after_merge!(canonical.id, duplicate.id)

        result = Result.new(
          dry_run: false,
          performed: true,
          canonical_id: canonical.id,
          duplicate_id: duplicate.id,
          canonical: canonical,
          duplicate: duplicate,
          movable_song_count: songs_moved,
          movable_customer_song_part_count: csp_moved + deduped,
          conflicting_customer_song_part_count: deduped,
          conflicts: plan.conflicts,
          planned_alias: plan.planned_alias,
          existing_alias: plan.existing_alias,
          deletable_song_master_id: duplicate.id,
          unknown_references: [],
          executable: true,
          aborted_reason: nil,
          songs_moved: songs_moved,
          customer_song_parts_moved: csp_moved,
          customer_song_parts_deduped: deduped,
          alias_created: alias_record.id
        )
      end

      report_result(result)
      result
    end

    # ---- 計画組み立て(dry_run / 本適用の事前判定で共用) --------------------------------

    def build_plan(canonical, duplicate)
      unknown = unknown_referencing_columns

      movable_song_count = duplicate ? Song.where(song_master_id: duplicate.id).count : 0
      duplicate_csps = duplicate ? CustomerSongPart.where(song_master_id: duplicate.id).to_a : []
      conflicts = duplicate && canonical ? conflict_plans(canonical.id, duplicate_csps) : []

      planned_alias =
        if duplicate
          AliasPlan.new(
            song_master_id: canonical&.id,
            normalized_song_name: duplicate.normalized_song_name,
            normalized_artist_name: duplicate.normalized_artist_name.to_s
          )
        end
      existing_alias =
        if duplicate
          SongMasterAlias.find_by(
            normalized_song_name: duplicate.normalized_song_name,
            normalized_artist_name: duplicate.normalized_artist_name.to_s
          )
        end

      reason = abort_reason(canonical, duplicate, unknown, conflicts, existing_alias)

      Result.new(
        dry_run: @dry_run,
        performed: false,
        canonical_id: @canonical_id,
        duplicate_id: @duplicate_id,
        canonical: canonical,
        duplicate: duplicate,
        movable_song_count: movable_song_count,
        movable_customer_song_part_count: duplicate_csps.size,
        conflicting_customer_song_part_count: conflicts.size,
        conflicts: conflicts,
        planned_alias: planned_alias,
        existing_alias: existing_alias,
        deletable_song_master_id: duplicate&.id,
        unknown_references: unknown,
        executable: reason.nil?,
        aborted_reason: reason,
        songs_moved: nil,
        customer_song_parts_moved: nil,
        customer_song_parts_deduped: nil,
        alias_created: nil
      )
    end

    def abort_reason(canonical, duplicate, unknown, conflicts, existing_alias)
      return "正SongMaster(##{@canonical_id})が存在しません" if canonical.nil?
      if duplicate.nil?
        return "統合元SongMaster(##{@duplicate_id})が存在しません" \
               "(既に統合済みかID誤りかを恒久証跡から判別できないため中止します)"
      end
      return "正と統合元が同じID(##{@canonical_id})です" if canonical.id == duplicate.id

      if existing_alias && ![canonical.id, duplicate.id].include?(existing_alias.song_master_id)
        return "統合元の正規化キー(#{existing_alias.normalized_song_name.inspect}, " \
               "#{existing_alias.normalized_artist_name.inspect})は別SongMaster(##{existing_alias.song_master_id})へ" \
               "解決するエイリアスに使われています。誤ったSongMasterへ統合しないよう中止します"
      end

      if unknown.any?
        return "song_masters を参照する未知の外部キーがあります: #{unknown.join(', ')}"
      end

      unresolvable = conflicts.reject(&:resolvable)
      if unresolvable.any?
        detail = unresolvable.map do |c|
          "customer_id=#{c.customer_id} part=#{c.part_name}(canonical song_id=#{c.canonical_song_id.inspect} / duplicate song_id=#{c.duplicate_song_id.inspect})"
        end.join("; ")
        return "内容が異なる CustomerSongPart の衝突があるため中止します(手動確認が必要): #{detail}"
      end

      nil
    end

    # canonical 側に既に存在する (customer_id, part_name) と衝突する duplicate 側 CustomerSongPart。
    def conflict_plans(canonical_id, duplicate_csps)
      canonical_by_key = CustomerSongPart.where(song_master_id: canonical_id)
        .index_by { |csp| [csp.customer_id, csp.part_name] }

      duplicate_csps.filter_map do |dup_csp|
        canonical_csp = canonical_by_key[[dup_csp.customer_id, dup_csp.part_name]]
        next if canonical_csp.nil?

        # 「同じ自己申告パートが正側にもある」ときだけ統合元側を重複扱いできる。
        # song_id は「登録時に選んだ具体的なSong(表示用)」であり、両方が非nilで食い違う場合だけ
        # "内容差異あり" とみなして自動デデュープを避ける(それ以外は正側を残して統合元側を削除)。
        song_ids_conflict =
          dup_csp.song_id.present? && canonical_csp.song_id.present? &&
          dup_csp.song_id != canonical_csp.song_id

        ConflictPlan.new(
          customer_id: dup_csp.customer_id,
          part_name: dup_csp.part_name,
          canonical_customer_song_part_id: canonical_csp.id,
          duplicate_customer_song_part_id: dup_csp.id,
          canonical_song_id: canonical_csp.song_id,
          duplicate_song_id: dup_csp.song_id,
          resolvable: !song_ids_conflict
        )
      end
    end

    # 衝突する duplicate 側 CustomerSongPart を削除する(正側は残す)。
    # abort_reason で resolvable? を確認済みなので、ここに来る衝突はすべてデデュープ可能。
    def dedupe_conflicting_customer_song_parts!(canonical_id, duplicate_id)
      duplicate_csps = CustomerSongPart.where(song_master_id: duplicate_id).to_a
      conflicts = conflict_plans(canonical_id, duplicate_csps)
      ids = conflicts.map(&:duplicate_customer_song_part_id)
      return 0 if ids.empty?

      CustomerSongPart.where(id: ids).delete_all
    end

    # ---- エイリアスの付け替え ------------------------------------------------------------

    # 統合元が解決先だったエイリアスを正へ移す。
    # song_master_aliases は (normalized_song_name, normalized_artist_name) にDBの複合UNIQUE制約が
    # あるため、正側と統合元側が「同じ正規化キーのエイリアス」を同時に持つことはありえない
    # (=移動時のキー衝突は構造上起きない。万一起きても update_all が RecordNotUnique を投げ、
    #  外側トランザクションごと安全にロールバックされる)。
    def move_aliases_to_canonical!(canonical_id, duplicate_id)
      SongMasterAlias.where(song_master_id: duplicate_id).update_all(song_master_id: canonical_id)
    end

    # 統合元の正規化キーを「正へ解決するエイリアス」として1件残す(旧表記のSongが再保存されても
    # 分裂SongMasterを作らせない)。別SongMasterを指す既存エイリアスは abort_reason で事前に弾いて
    # いるため、ここに来る既存エイリアスは正 or (直前に移動した)統合元由来のものだけ。
    def upsert_legacy_key_alias!(canonical, duplicate)
      normalized_song_name = duplicate.normalized_song_name
      normalized_artist_name = duplicate.normalized_artist_name.to_s

      record = SongMasterAlias.find_by(
        normalized_song_name: normalized_song_name,
        normalized_artist_name: normalized_artist_name
      )
      if record
        record.update!(song_master_id: canonical.id) if record.song_master_id != canonical.id
        record
      else
        SongMasterAlias.create!(
          song_master_id: canonical.id,
          normalized_song_name: normalized_song_name,
          normalized_artist_name: normalized_artist_name
        )
      end
    end

    # ---- 検算 ------------------------------------------------------------------------

    def verify_no_known_references!(duplicate_id)
      remaining = {
        "songs" => Song.where(song_master_id: duplicate_id).count,
        "customer_song_parts" => CustomerSongPart.where(song_master_id: duplicate_id).count,
        "song_master_aliases" => SongMasterAlias.where(song_master_id: duplicate_id).count
      }.select { |_table, count| count.positive? }
      return if remaining.empty?

      raise "統合元SongMaster(##{duplicate_id})への既知参照が残っています: #{remaining.inspect}"
    end

    def verify_no_unknown_references!
      unknown = unknown_referencing_columns
      return if unknown.empty?

      raise "song_masters を参照する未知の外部キーがあります: #{unknown.join(', ')}"
    end

    def verify_after_merge!(canonical_id, duplicate_id)
      errors = []
      errors << "統合元SongMaster(##{duplicate_id})が削除されていません" if SongMaster.exists?(duplicate_id)
      errors << "正SongMaster(##{canonical_id})が失われました" unless SongMaster.exists?(canonical_id)
      errors << "統合元を指すSongが残っています" if Song.where(song_master_id: duplicate_id).exists?
      errors << "統合元を指すCustomerSongPartが残っています" if CustomerSongPart.where(song_master_id: duplicate_id).exists?
      return if errors.empty?

      raise "統合後の検算に失敗しました: #{errors.join(' / ')}"
    end

    # ---- 参照カラムの探索 -----------------------------------------------------------

    # song_masters を参照している全外部キーカラム("table.column")のうち、
    # このサービスが付け替えを行う既知集合(KNOWN_REFERENCING_COLUMNS)に無いものを返す。
    # 1件でもあれば統合を中止する(未知の参照を壊さない)。
    def unknown_referencing_columns
      referencing_columns - KNOWN_REFERENCING_COLUMNS
    end

    # schema上のFK定義から song_masters を参照しているカラムを列挙する。
    # sqlite3 / mysql2 のどちらのアダプタでも connection.foreign_keys は利用可能。
    def referencing_columns
      connection = ActiveRecord::Base.connection
      connection.tables.flat_map do |table|
        connection.foreign_keys(table)
          .select { |fk| fk.to_table.to_s == "song_masters" }
          .map { |fk| "#{table}.#{fk.column}" }
      end
    rescue StandardError => e
      log("[warn] 参照FKの探索に失敗しました(既知参照のみを対象にします): #{e.class}: #{e.message}")
      KNOWN_REFERENCING_COLUMNS.dup
    end

    # ---- ログ ----------------------------------------------------------------------

    def report_plan(plan)
      log("== 統合予定 (#{plan.dry_run ? 'DRY RUN / read-only' : '本適用の事前判定'}) ==")
      log("正SongMaster: #{describe(plan.canonical)}")
      log("統合元SongMaster: #{describe(plan.duplicate)}")
      log("移動対象Song: #{plan.movable_song_count}件")
      log("移動対象CustomerSongPart: #{plan.movable_customer_song_part_count}件")
      log("CustomerSongPartのUNIQUE衝突: #{plan.conflicting_customer_song_part_count}件")
      plan.conflicts.each do |c|
        log("  - customer_id=#{c.customer_id} part=#{c.part_name} " \
            "canonical_csp=##{c.canonical_customer_song_part_id} duplicate_csp=##{c.duplicate_customer_song_part_id} " \
            "resolvable=#{c.resolvable}")
      end
      if plan.planned_alias
        log("作成予定Alias: song_master_id=##{plan.planned_alias.song_master_id} " \
            "key=(#{plan.planned_alias.normalized_song_name.inspect}, #{plan.planned_alias.normalized_artist_name.inspect}) " \
            "#{plan.existing_alias ? '(既存あり: 変更なし)' : ''}")
      end
      log("削除予定SongMaster: #{plan.deletable_song_master_id ? "##{plan.deletable_song_master_id}" : 'なし'}")
      log("未知の参照: #{plan.unknown_references.any? ? plan.unknown_references.join(', ') : 'なし'}")
      log("実行可能: #{plan.executable?}")
      log("中止理由: #{plan.aborted_reason || 'なし'}")
    end

    def report_result(result)
      if result.nil?
        log("== 結果を組み立てられませんでした ==")
        return
      end

      if result.performed
        log("== 統合完了 ==")
        log("移動したSong: #{result.songs_moved}件")
        log("移動したCustomerSongPart: #{result.customer_song_parts_moved}件 / デデュープ: #{result.customer_song_parts_deduped}件")
        log("Alias: ##{result.alias_created}")
        log("削除したSongMaster: ##{result.duplicate_id}")
      else
        log("== 実行不可のため何もしていません: #{result.aborted_reason} ==")
      end
    end

    def describe(master)
      return "なし" if master.nil?

      "##{master.id} song_name=#{master.song_name.inspect} artist_name=#{master.artist_name.inspect} " \
        "normalized=(#{master.normalized_song_name.inspect}, #{master.normalized_artist_name.inspect})"
    end

    def log(message)
      @logger.call(message)
    end
  end
end
