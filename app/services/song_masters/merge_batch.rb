module SongMasters
  # 分裂SongMasterの「keep(正) <- merge(統合元)」ペアを複数まとめて、
  # 「全ペア単一トランザクション・1組でも失敗したら全ロールバック」で統合する。
  #
  # 使い方は rake song_masters:merge_pairs 経由。統合対象のIDペアは必ず MERGE_PAIRS で明示的に渡す
  # (このサービス/タスクは本番IDをハードコードせず、全SongMasterや検出候補を自動統合しない)。
  #
  # 実行モード:
  #   - 既定は DRY RUN(DBを一切変更しない)。
  #   - 本適用は APPLY=true と CONFIRM=MERGE_SONG_MASTERS の「両方」が必須。
  #     片方だけ・DRY_RUN との矛盾・中途半端な指定は黙ってDRY RUNに落とさずエラーにする。
  #
  # DRY RUN:
  #   1. MERGE_PAIRS の形式・意味(数値/形式/同一ID/ペア重複/keep重複/merge重複/keepとmergeの交差)を検証
  #   2. 各ペアを SongMasters::Merge の dry_run で preflight(存在・未知FK・CSP衝突・エイリアス衝突)
  #   3. 全ペアのシミュレーション結果を出力
  #   4. 1組でも実行不能なら全体を ready: false
  #   5. DB変更は0件(read-only。念のためトランザクションで囲みロールバックする)
  #
  # 本適用(APPLY):
  #   1. 本適用条件(APPLY/CONFIRM)を検証
  #   2. 単一の外側トランザクションを開始
  #   3. 関係するSongMaster行を id 昇順でまとめてロック(デッドロック回避)
  #   4. 全ペアを再度 preflight。1組でも実行不能なら中止(=全ロールバック)
  #   5. 各ペアを SongMasters::Merge の本適用で統合(内側トランザクションは requires_new を使わないため
  #      外側に参加する。例外は外側まで伝播し全ペアがロールバックされる)
  #   6. 全ペアの事後検算(keep 実在 / merge 削除済み / merge への songs・customer_song_parts 参照0件)
  #   7. いずれかで失敗したら Aborted を投げ、外側トランザクションごと全ロールバック
  class MergeBatch
    CONFIRM_PHRASE = "MERGE_SONG_MASTERS".freeze

    # 環境変数・MERGE_PAIRS の指定ミス(実行前に弾く)。
    class ConfigError < StandardError; end
    # preflight / 本適用 / 事後検算での中止(全ペアをロールバック)。
    class Aborted < StandardError; end

    Pair = Struct.new(:keep_id, :merge_id, keyword_init: true) do
      def label
        "#{keep_id}:#{merge_id}"
      end
    end

    BatchResult = Struct.new(
      :apply, :ready, :applied, :aborted_reason, :pair_results,
      keyword_init: true
    )

    def self.from_env(env:, logger: ->(_message) {})
      apply = resolve_apply_mode(env)
      pairs = parse_pairs(env["MERGE_PAIRS"])
      new(pairs: pairs, apply: apply, logger: logger)
    end

    # APPLY / CONFIRM / DRY_RUN から本適用かどうかを決める。
    # 中途半端・矛盾した指定は黙ってDRY RUNにせず ConfigError にする。
    def self.resolve_apply_mode(env)
      raw_apply = env["APPLY"]
      raw_confirm = env["CONFIRM"]
      raw_dry = env["DRY_RUN"]

      if raw_apply && !%w[true false].include?(raw_apply)
        raise ConfigError, %(APPLY は "true" か "false" で指定してください(現在: #{raw_apply.inspect}))
      end
      if raw_dry && !%w[true false].include?(raw_dry)
        raise ConfigError, %(DRY_RUN は "true" か "false" で指定してください(現在: #{raw_dry.inspect}))
      end

      apply = raw_apply == "true" && raw_confirm == CONFIRM_PHRASE

      if apply
        if raw_dry == "true"
          raise ConfigError, "APPLY=true と DRY_RUN=true は同時に指定できません"
        end
        return true
      end

      # ここから下は「本適用ではない」。本適用を意図したように見える中途半端な指定はエラーにする。
      if raw_apply == "true"
        raise ConfigError,
          "APPLY=true には CONFIRM=#{CONFIRM_PHRASE} が必要です(本適用しません)"
      end
      if raw_confirm == CONFIRM_PHRASE
        raise ConfigError,
          "CONFIRM=#{CONFIRM_PHRASE} だけでは本適用できません。APPLY=true も指定してください" \
          "(本適用しない場合は CONFIRM を外してください)"
      end
      if raw_confirm && raw_confirm != CONFIRM_PHRASE
        raise ConfigError, %(CONFIRM の値が不正です(現在: #{raw_confirm.inspect}))
      end
      if raw_dry == "false"
        raise ConfigError,
          "DRY_RUN=false だけでは本適用できません。本適用は APPLY=true CONFIRM=#{CONFIRM_PHRASE} を指定してください"
      end

      false
    end

    # "keep:merge,keep:merge,..." を Pair の配列にする。指定ミスは ConfigError。
    def self.parse_pairs(raw)
      if raw.nil? || raw.strip.empty?
        raise ConfigError, "MERGE_PAIRS を指定してください(例: MERGE_PAIRS=\"43:398,93:102\")"
      end

      tokens = raw.split(",", -1) # 末尾カンマ等の空要素も検出する
      tokens.each do |token|
        if token.strip.empty?
          raise ConfigError, "MERGE_PAIRS に空の要素または余分な区切り文字があります: #{raw.inspect}"
        end
      end

      pairs = tokens.map { |token| parse_token(token) }

      seen = []
      pairs.each do |pair|
        if seen.include?([pair.keep_id, pair.merge_id])
          raise ConfigError, "MERGE_PAIRS に同じペアが重複しています: #{pair.label}"
        end
        seen << [pair.keep_id, pair.merge_id]
      end

      merge_ids = pairs.map(&:merge_id)
      duplicate_merge_ids = merge_ids.tally.select { |_id, count| count > 1 }.keys
      if duplicate_merge_ids.any?
        raise ConfigError,
          "MERGE_PAIRS に同じ merge ID が複数あります(1つの merge を複数へは統合できません): #{duplicate_merge_ids.join(', ')}"
      end

      keep_ids = pairs.map(&:keep_id)
      duplicate_keep_ids = keep_ids.tally.select { |_id, count| count > 1 }.keys
      if duplicate_keep_ids.any?
        raise ConfigError,
          "MERGE_PAIRS に同じ keep ID が複数あります(3-way以上の統合は複数回に分けて実行してください): #{duplicate_keep_ids.join(', ')}"
      end

      crossing = (keep_ids & merge_ids).uniq
      if crossing.any?
        raise ConfigError,
          "MERGE_PAIRS の keep と merge に同じIDが跨って出現します(連鎖・循環は不可): #{crossing.join(', ')}"
      end

      pairs
    end

    def self.parse_token(token)
      match = token.match(/\A\s*(\d+)\s*:\s*(\d+)\s*\z/)
      if match.nil?
        raise ConfigError,
          %(MERGE_PAIRS の要素は "keep:merge"(いずれも正の整数)で指定してください: #{token.inspect})
      end

      keep_id = Integer(match[1], 10)
      merge_id = Integer(match[2], 10)
      if keep_id < 1 || merge_id < 1
        raise ConfigError, "MERGE_PAIRS の SongMaster ID は1以上で指定してください: #{token.inspect}"
      end
      if keep_id == merge_id
        raise ConfigError, "MERGE_PAIRS の keep と merge が同一IDです: #{token.inspect}"
      end

      Pair.new(keep_id: keep_id, merge_id: merge_id)
    end

    def initialize(pairs:, apply:, logger: ->(_message) {})
      @pairs = pairs
      @apply = apply
      @logger = logger
    end

    def apply?
      @apply
    end

    def call
      @apply ? run_apply : run_dry_run
    end

    private

    def run_dry_run
      pair_results = []
      ActiveRecord::Base.transaction do
        pair_results = @pairs.map { |pair| merge_call(pair, dry_run: true) }
        raise ActiveRecord::Rollback
      end

      ready = pair_results.all?(&:executable?)
      log("== DRY RUN 集計: #{@pairs.size}組中 実行可能 #{pair_results.count(&:executable?)}組" \
          " / 実行不可 #{pair_results.count { |result| !result.executable? }}組 ==")
      log(ready ? "全ペア実行可能です" : "実行不可のペアがあるため、本適用は全体が中止されます")

      BatchResult.new(apply: false, ready: ready, applied: false, aborted_reason: nil, pair_results: pair_results)
    end

    def run_apply
      applied = []

      begin
        ActiveRecord::Base.transaction do
          lock_all_song_masters!

          blocked = @pairs.map { |pair| merge_call(pair, dry_run: true) }.reject(&:executable?)
          if blocked.any?
            raise Aborted, "preflightで実行不可のペアがあります: " +
              blocked.map { |result| "#{result.canonical_id}:#{result.duplicate_id}(#{result.aborted_reason})" }.join(" / ")
          end

          @pairs.each do |pair|
            result = merge_call(pair, dry_run: false)
            unless result.performed
              raise Aborted, "ペア #{pair.label} の統合に失敗しました: #{result.aborted_reason || '理由不明'}"
            end
            applied << result
          end

          verify_all_pairs!
        end
      rescue Aborted, ActiveRecord::ActiveRecordError, RuntimeError => e
        # 想定した中止(Aborted)も、統合中の想定外例外も、外側トランザクションごと
        # 全ペアをロールバックしたうえで「本適用しなかった」として返す(部分適用を残さない)。
        log("!! 中止しました。#{@pairs.size}組すべてをロールバックしました: #{e.class}: #{e.message}")
        return BatchResult.new(
          apply: true, ready: false, applied: false,
          aborted_reason: "#{e.class}: #{e.message}", pair_results: []
        )
      end

      log("== 本適用完了: #{applied.size}組を統合しました ==")
      BatchResult.new(apply: true, ready: true, applied: true, aborted_reason: nil, pair_results: applied)
    end

    def lock_all_song_masters!
      ids = @pairs.flat_map { |pair| [pair.keep_id, pair.merge_id] }.uniq.sort
      SongMaster.lock.where(id: ids).order(:id).load
    end

    # 全ペアの事後検算。1組でも崩れていれば全ロールバック。
    def verify_all_pairs!
      errors = []
      @pairs.each do |pair|
        errors << "keep ##{pair.keep_id} が存在しません" unless SongMaster.exists?(pair.keep_id)
        errors << "merge ##{pair.merge_id} が削除されていません" if SongMaster.exists?(pair.merge_id)
        if Song.where(song_master_id: pair.merge_id).exists?
          errors << "merge ##{pair.merge_id} を指すSongが残っています"
        end
        if CustomerSongPart.where(song_master_id: pair.merge_id).exists?
          errors << "merge ##{pair.merge_id} を指すCustomerSongPartが残っています"
        end
      end
      raise Aborted, "事後検算に失敗しました: #{errors.join(' / ')}" if errors.any?
    end

    def merge_call(pair, dry_run:)
      log("")
      log("=== ペア #{pair.label} (merge ##{pair.merge_id} -> keep ##{pair.keep_id}) ===")
      SongMasters::Merge.call(
        canonical_id: pair.keep_id,
        duplicate_id: pair.merge_id,
        dry_run: dry_run,
        logger: @logger
      )
    end

    def log(message)
      @logger.call(message)
    end
  end
end
