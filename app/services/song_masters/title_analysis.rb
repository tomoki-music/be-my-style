module SongMasters
  # 本番/ローカルのSongを read-only で走査し、曲名の表記パターンと、Resolver改善による
  # SongMaster集約の変化を集計してレポートするだけのサービス。DBは一切変更しない。
  #
  #   bundle exec rails song_masters:analyze_titles
  #
  # 出力する情報は Song ID・song_name・artist_name のみ(個人情報は出力しない)。
  #
  # 「改善前(legacy)」は PR #156 時点の Resolver、すなわち
  #   - アーティスト名欄が入力済みなら分解しない
  #   - 末尾「曲名（アーティスト名）」だけを、告知語でなく かつ 裏付けがある場合に分解
  # 相当の挙動をこのファイル内の legacy_identity で再現して比較する
  # (区切り「A - B」「A / B」・先頭注記「【Key+4】」の分解は改善後にのみ効く)。
  class TitleAnalysis
    Result = Struct.new(
      :song_total,
      :pattern_counts,           # { pattern_symbol => count }
      :leading_annotation_counts, # { "【Key+4】" => count, ... }
      :hyphen_form_count, :slash_form_count, :paren_form_count, :bracket_title_count,
      :legacy_master_count, :improved_master_count,
      :consolidated_song_count,
      :mergeable_examples,       # 裏付けにより統合されるSong例
      :ambiguous_examples,       # 両向き成立で分解しないSong例
      :no_corroboration_examples,# 裏付けが無く分解しないSong例
      :protected_examples,       # 正式タイトルの可能性があり保護するSong例
      :suspicious_groups,        # 誤統合の疑いがあるグループ
      keyword_init: true
    )

    Row = Struct.new(:song_id, :song_name, :artist_name, keyword_init: true)

    EXAMPLE_LIMIT = 40

    def self.call(logger: ->(_msg) {})
      new(logger: logger).call
    end

    def initialize(logger:)
      @logger = logger
    end

    def call
      songs = Song.order(:id).pluck(:id, :song_name, :artist_name).map do |id, song_name, artist_name|
        Row.new(song_id: id, song_name: song_name.to_s, artist_name: artist_name.to_s.presence)
      end

      corroboration = SongMasters::ArtistCorroboration.build(
        songs: songs.map { |row| [row.song_name, row.artist_name] }
      )

      pattern_counts = Hash.new(0)
      leading_annotation_counts = Hash.new(0)
      hyphen = slash = paren = bracket_title = 0

      legacy_keys = Hash.new(0)
      improved_keys = Hash.new(0)
      consolidated = 0

      mergeable = []
      ambiguous = []
      no_corroboration = []
      protected_titles = []
      improved_groups = Hash.new { |h, k| h[k] = [] }

      songs.each do |row|
        raw = row.song_name.strip
        classify_patterns(row, raw).each { |pattern| pattern_counts[pattern] += 1 }

        annotation = leading_annotation_token(raw)
        leading_annotation_counts[annotation] += 1 if annotation

        hyphen += 1 if hyphen_form?(raw)
        slash += 1 if slash_form?(raw)
        paren += 1 if SongMasters::Resolver.parse_embedded_artist(raw)
        bracket_title += 1 if raw.match?(/[「『][^「『」』]+[」』]/)

        legacy = legacy_identity(row, corroboration)
        improved = SongMasters::Resolver.identity_for(
          song_name: row.song_name, artist_name: row.artist_name, artist_corroboration: corroboration
        )

        legacy_key = identity_key(legacy)
        improved_key = identity_key(improved)
        legacy_keys[legacy_key] += 1 if legacy_key
        improved_keys[improved_key] += 1 if improved_key
        improved_groups[improved_key] << row if improved_key

        next if improved_key.nil?

        if improved_key != legacy_key
          consolidated += 1
          mergeable << row if mergeable.size < EXAMPLE_LIMIT
        elsif decomposable_structure?(raw) && row.artist_name.blank?
          if ambiguous_direction?(raw, corroboration)
            ambiguous << row if ambiguous.size < EXAMPLE_LIMIT
          elsif protectable_official_title?(raw)
            protected_titles << row if protected_titles.size < EXAMPLE_LIMIT
          else
            no_corroboration << row if no_corroboration.size < EXAMPLE_LIMIT
          end
        end
      end

      suspicious = detect_suspicious_groups(improved_groups)

      result = Result.new(
        song_total: songs.size,
        pattern_counts: pattern_counts,
        leading_annotation_counts: leading_annotation_counts,
        hyphen_form_count: hyphen,
        slash_form_count: slash,
        paren_form_count: paren,
        bracket_title_count: bracket_title,
        legacy_master_count: legacy_keys.size,
        improved_master_count: improved_keys.size,
        consolidated_song_count: consolidated,
        mergeable_examples: mergeable,
        ambiguous_examples: ambiguous,
        no_corroboration_examples: no_corroboration,
        protected_examples: protected_titles,
        suspicious_groups: suspicious
      )
      report(result)
      result
    end

    private

    def identity_key(identity)
      return nil if identity.nil?

      [identity.normalized_song_name, identity.normalized_artist_name]
    end

    # PR #156 時点の Resolver 相当(末尾「曲名（アーティスト名）」のみを裏付けありで分解。
    # 区切り「A - B」「A / B」・先頭注記・鉤括弧の分解は無し)。
    # 裏付けの供給源は改善後と同じ(別カラムSong + 末尾括弧 + 既存SongMaster)にして、
    # before/after の差分が「区切り/注記の分解」だけに起因するようにする。
    def legacy_identity(row, corroboration)
      song_name = row.song_name
      artist_name = row.artist_name

      if artist_name.blank? && (parsed = SongMasters::Resolver.parse_embedded_artist(song_name))
        title, embedded_artist = parsed
        unless SongMasters::Resolver.announcement_like?(embedded_artist)
          nsn = SongMasters::Resolver.normalize(title)
          nan = SongMasters::Resolver.normalize(embedded_artist)
          if nsn.present? && nan.present? &&
             corroboration.call(normalized_song_name: nsn, normalized_artist_name: nan)
            song_name = title
            artist_name = embedded_artist
          end
        end
      end

      nsn = SongMasters::Resolver.normalize(song_name)
      return nil if nsn.blank?

      SongMasters::Resolver::Identity.new(
        normalized_song_name: nsn,
        normalized_artist_name: SongMasters::Resolver.normalize(artist_name),
        song_name: song_name.to_s.strip,
        artist_name: artist_name.to_s.strip.presence
      )
    end

    def classify_patterns(row, raw)
      patterns = []
      patterns << :split_column if row.artist_name.present?
      if (parsed = SongMasters::Resolver.parse_embedded_artist(raw))
        patterns << (SongMasters::Resolver.announcement_like?(parsed[1]) ? :embedded_paren_announcement : :embedded_paren)
      end
      patterns << :bracket_title if raw.match?(/[「『][^「『」』]+[」』]/)
      patterns << :separator if SongMasters::Resolver.separator_splits(raw).any?
      patterns << :leading_annotation if leading_annotation_token(raw)
      patterns << :plain if patterns.empty?
      patterns
    end

    def leading_annotation_token(raw)
      match = raw.match(SongMasters::Resolver::LEADING_ANNOTATION_PATTERN)
      return nil if match.nil? || match[0].strip.blank?

      match[0].strip
    end

    def hyphen_form?(raw)
      raw.match?(/[[:space:]]-[[:space:]]|[[:space:]]*[–—][[:space:]]*/)
    end

    def slash_form?(raw)
      raw.match?(%r{[[:space:]]*[/／][[:space:]]*})
    end

    def decomposable_structure?(raw)
      SongMasters::Resolver.separator_splits(raw).any? ||
        SongMasters::Resolver.parse_embedded_artist(raw) ||
        leading_annotation_token(raw) ||
        raw.match?(/[「『][^「『」』]+[」』]/)
    end

    def ambiguous_direction?(raw, corroboration)
      SongMasters::Resolver.separator_splits(raw).any? do |left, right|
        both = [[left, right], [right, left]].select do |title, artist|
          nsn = SongMasters::Resolver.normalize(title)
          nan = SongMasters::Resolver.normalize(artist)
          nan.present? && corroboration.call(normalized_song_name: nsn, normalized_artist_name: nan)
        end
        both.size >= 2
      end
    end

    def protectable_official_title?(raw)
      raw.match?(/\Afeat\./i) || raw.match?(/[^[:space:]]feat\.[^[:space:]]/i) ||
        raw.match?(/[[:alnum:]]-[[:alnum:]]/) # スペース無しハイフン(Anti-Hero等)
    end

    # 改善後に同じ SongMaster へ入る Song 群のうち、元の曲名の「緩いキー」が
    # 2種類以上に割れているグループを「誤統合の疑い」として拾う。
    def detect_suspicious_groups(improved_groups)
      improved_groups.filter_map do |key, rows|
        next if rows.size < 2

        loose = rows.map { |row| loose_key(row.song_name) }.uniq
        next if loose.size < 2

        { key: key, rows: rows.first(EXAMPLE_LIMIT) }
      end
    end

    def loose_key(song_name)
      song_name.to_s.unicode_normalize(:nfkc).downcase
        .gsub(/[【〔［\[(（][^】〕］\])）]*[】〕］\])）]/, "")
        .gsub(/[[:space:]]/, "")
        .gsub(/[\p{Punct}\p{S}]/, "")
    end

    def report(result)
      log "== SongMaster 表記分析 (read-only / DBは変更していません) =="
      log "対象Song: #{result.song_total}件"
      log ""
      log "1. 表記パターン別件数 (1曲が複数パターンに該当することがあります)"
      result.pattern_counts.sort_by { |_k, v| -v }.each { |pattern, count| log "   #{pattern}: #{count}件" }
      log ""
      log "2. 先頭注記の種類と件数"
      if result.leading_annotation_counts.empty?
        log "   (なし)"
      else
        result.leading_annotation_counts.sort_by { |_k, v| -v }.each { |token, count| log "   #{token.inspect}: #{count}件" }
      end
      log ""
      log "3. 区切り形式の件数"
      log "   ハイフン/ダッシュ形式: #{result.hyphen_form_count}件"
      log "   スラッシュ形式: #{result.slash_form_count}件"
      log "   末尾「曲名（アーティスト）」形式: #{result.paren_form_count}件"
      log "   鉤括弧「」『』形式: #{result.bracket_title_count}件"
      log ""
      log_examples("4. 裏付けにより統合されるSong(改善後にidentityが変わる)", result.mergeable_examples)
      log_examples("5. 両向きに解釈でき分解しない曖昧Song", result.ambiguous_examples)
      log_examples("6. 裏付けが無く分解しないSong", result.no_corroboration_examples)
      log_examples("7. 正式タイトルの可能性があり保護するSong", result.protected_examples)
      log ""
      log "8. SongMaster作成予定数: 改善前 #{result.legacy_master_count}件 -> 改善後 #{result.improved_master_count}件"
      log "9. 改善により別キーへ統合されるSong: #{result.consolidated_song_count}件"
      log ""
      log "10. 誤統合の疑いがあるグループ(同一SongMasterに曲名の緩いキーが2種以上)"
      if result.suspicious_groups.empty?
        log "   (疑いなし)"
      else
        result.suspicious_groups.each do |group|
          log "   normalized=#{group[:key].inspect}"
          group[:rows].each { |row| log "     Song##{row.song_id} #{row.song_name.inspect} / #{row.artist_name.inspect}" }
        end
      end
      log ""
      log "完了しました(データは変更していません)。"
    end

    def log_examples(title, rows)
      log title
      if rows.empty?
        log "   (該当なし)"
      else
        rows.each { |row| log "   Song##{row.song_id} #{row.song_name.inspect} / #{row.artist_name.inspect}" }
      end
    end

    def log(message)
      @logger.call(message)
    end
  end
end
