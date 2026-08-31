module SongMasters
  # Songの曲名・アーティスト名から共通楽曲マスター(SongMaster)を解決する。
  #
  # Songはイベントごとに別レコードとして作られる(belongs_to :event)ため、同じ曲を
  # 別イベントで演奏しても素のsong_idでは「同じ曲」と判定できない。曲名・アーティスト名を
  # NFKC正規化(全角/半角・大文字小文字のゆれを吸収)したキーでSongMasterへ集約することで、
  # イベントをまたいだ演奏実績の集計・経験者検索を可能にする。
  #
  # 正規化は「表記ゆれの吸収」を優先しており、同名異曲(同タイトル・同アーティスト表記の
  # 別の曲)まで区別する精度は持たない。曲名だけでなくアーティスト名も一致条件に含めることで
  # 誤判定のリスクを下げているが、完全な同一性保証ではない前提で利用すること。
  #
  # 曲名の中にアーティスト名や注記が混ざった表記(「アーティスト - 曲名」「曲名（アーティスト）」
  # 「【Key+4】曲名」等)の分解は、文字列だけを見て推測しない。「曲名」と「アーティスト名」が
  # 別カラムで入力されたSongや既存SongMasterという"裏付け"がある向き・候補のときだけ分解する
  # (裏付けの供給は artist_corroboration: 経由。既定は既存SongMasterの完全一致)。
  # 裏付けが無い/両方向に成立する曖昧なケースでは分解せず、元の文字列をそのまま1曲として扱う。
  class Resolver
    # 引用符・アポストロフィの表記ゆれを吸収するためのマッピング。
    # 全角引用符(＇＂)や全角ダブルクォートはNFKC正規化で半角に変換されるためここには含めないが、
    # 以下の「カーブクォート(スマートクォート)」系はNFKC(canonical decomposition非対象の
    # compatibility文字ではない)では変換されないため、明示的にASCII表記へ寄せる。
    # 例: "Rock'n'Roll" と "Rock’n’Roll"(U+2019) を同一キーとして扱う。
    QUOTE_NORMALIZATION_MAP = {
      "‘" => "'",  # ‘ LEFT SINGLE QUOTATION MARK
      "’" => "'",  # ’ RIGHT SINGLE QUOTATION MARK
      "‚" => "'",  # ‚ SINGLE LOW-9 QUOTATION MARK
      "‛" => "'",  # ‛ SINGLE HIGH-REVERSED-9 QUOTATION MARK
      "′" => "'",  # ′ PRIME
      "ʼ" => "'",  # ʼ MODIFIER LETTER APOSTROPHE
      "`" => "'",  # ` GRAVE ACCENT
      "´" => "'",  # ´ ACUTE ACCENT
      "“" => "\"", # “ LEFT DOUBLE QUOTATION MARK
      "”" => "\"", # ” RIGHT DOUBLE QUOTATION MARK
      "„" => "\"", # „ DOUBLE LOW-9 QUOTATION MARK
      "‟" => "\"", # ‟ DOUBLE HIGH-REVERSED-9 QUOTATION MARK
      "″" => "\"", # ″ DOUBLE PRIME
    }.freeze
    QUOTE_NORMALIZATION_PATTERN = Regexp.union(QUOTE_NORMALIZATION_MAP.keys).freeze

    # 「曲名（アーティスト名）」形式(末尾の丸括弧にアーティスト名を書き、アーティスト名欄は空)を
    # 「曲名」+アーティスト名欄 と同じキーへ寄せるためのパターン。半角/全角括弧の両対応。
    # 括弧の中身・括弧より前の曲名がいずれも非空のときだけ分解する(誤った切り出しを避ける)。
    #
    # ただしこのパターンに一致しても、括弧内を無条件にアーティスト名として切り出すことはしない。
    # 括弧内が告知・募集・キー/バージョン等の付随情報である場合や、「曲名」+「そのアーティスト名」の
    # 組み合わせを裏付ける既存データが無い場合は分解しない(decompose参照)。
    EMBEDDED_ARTIST_PATTERN = /\A(?<title>.+?)[[:space:]]*[(（](?<artist>[^()（）]+)[)）][[:space:]]*\z/

    # 「アーティスト「曲名」」「アーティスト『曲名』」形式。鉤括弧の中身を曲名候補、手前をアーティスト
    # 候補として扱う(向きの採用可否はあくまで裏付け照合で決める)。
    BRACKET_TITLE_PATTERN = /\A(?<before>.+?)[[:space:]]*[「『](?<inside>[^「『」』]+)[」』][[:space:]]*\z/

    # 「アーティスト - 曲名」「曲名 / アーティスト」等の区切り。どちらが曲名/アーティストかは
    # 文字列だけでは決めず(separator_splitsは構造分解のみ)、両向きを候補にして裏付け照合で決める。
    # - 素のハイフン("-")は曲名の一部(Anti-Hero, Spider-Man等)であることが多いため前後スペース必須。
    # - ダッシュ(–, —)・スラッシュ(/, ／)は区切り用途が支配的なため前後スペースは任意。
    SEPARATOR_PATTERN = %r{[[:space:]]+-[[:space:]]+|[[:space:]]*[–—][[:space:]]*|[[:space:]]*[/／][[:space:]]*}

    # 曲名先頭の注記(【Key+4】【時間に余裕があれば】【募集中】(原曲キー)等)。1つ以上連続していても剥がす。
    # ここで剥がすのは identity 計算時の"候補"を作るためだけで、Songやマスターの表示名は変更しない。
    # 剥がした候補を採用するかどうかは、その候補が裏付け照合に通るかどうかで決める
    # (正式タイトルの一部である先頭括弧を無条件に落とさないための設計)。
    LEADING_ANNOTATION_PATTERN = /\A(?:[[:space:]]*[【〔［\[(（][^】〕］\])）【〔［\[(（]*[】〕］\])）])+/

    # 括弧内文字列が「アーティスト名ではなく告知・補足情報」に見えるかどうかの安全網。
    # ここに列挙した語・記号・日付らしい表記のいずれかを含む場合はアーティスト名として扱わない。
    # これは主たる判定ではなく(主たる判定は既存データとの照合)、誤って告知文言をアーティストとして
    # 切り出すことへの防御として使う。過剰に弾いても「括弧込みの曲名をそのまま1曲扱いにする」
    # という安全側の挙動になるだけなので、疑わしいものは広めに含める。
    ANNOUNCEMENT_KEYWORDS = %w[
      募集 急募 練習 リハ リクエスト request
      キー key 原曲 半音 移調 カポ capo 転調 コード
      バージョン version ver アレンジ arrange アコースティック acoustic
      インスト instrumental カラオケ offvocal オフボーカル
      ライブ live セッション session
      デュエット duet パート part コーラス chorus ハモリ ソロ solo 掛け合い
      担当 歓迎 新歓 送別 忘年 新年 打ち上げ 発表会 大会 記念 開催
      前祝 祝 お披露目 コラボ 予定 予告 告知 決定 未定 tbd 仮 変更 追加
    ].freeze
    ANNOUNCEMENT_PATTERN = Regexp.union(
      Regexp.union(ANNOUNCEMENT_KEYWORDS),
      /[!！?？♪♫♬〜~]/,
      /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}]/,
      /\d{1,4}[\/.\-年月日:：]/
    ).freeze

    # 「曲名(正規化済)」+「アーティスト名(正規化済)」の組み合わせに、既存SongMasterという
    # 裏付けがあるかどうかを返すデフォルト実装。曲名からのアーティスト/注記分解の可否判定に使う。
    # backfill等、DBに未反映のSong情報も裏付けに含めたい呼び出し元は、同じシグネチャの
    # 別オブジェクト(lambda等)を artist_corroboration: で差し込む。
    DEFAULT_ARTIST_CORROBORATION = lambda do |normalized_song_name:, normalized_artist_name:|
      next false if normalized_artist_name.blank?

      SongMaster.exists?(
        normalized_song_name: normalized_song_name,
        normalized_artist_name: normalized_artist_name
      )
    end

    # 正規化済みキー(SongMasterの一意キー)と、SongMaster新規作成時に使う表示名をまとめた値オブジェクト。
    Identity = Struct.new(:normalized_song_name, :normalized_artist_name, :song_name, :artist_name, keyword_init: true)

    def self.call(song_name:, artist_name:, artist_corroboration: DEFAULT_ARTIST_CORROBORATION)
      new(song_name, artist_name, artist_corroboration: artist_corroboration).call
    end

    # DBを一切変更せず、既存のSongMasterだけを解決する(該当が無ければnil)。
    # backfill等のdry-run用途で、find_or_createによる意図しないSongMaster作成を避けるために使う。
    def self.resolve_existing(song_name:, artist_name:, artist_corroboration: DEFAULT_ARTIST_CORROBORATION)
      identity = identity_for(song_name: song_name, artist_name: artist_name, artist_corroboration: artist_corroboration)
      return nil if identity.nil?

      existing_master_for(identity.normalized_song_name, identity.normalized_artist_name)
    end

    # 正規化キーからSongMasterを引く。通常の完全一致(song_masters)で見つからなければ、
    # 「旧表記の正規化キー -> 正SongMaster」のエイリアス(song_master_aliases)を引く。
    #
    # エイリアスは SongMasters::Merge が分裂SongMasterを統合したときにだけ作られる。
    # song_masters の完全一致を常に優先するため、実在するSongMasterがエイリアスに
    # 上書きされることはない(統合で削除された旧キーだけがエイリアス経由で解決される)。
    def self.existing_master_for(normalized_song_name, normalized_artist_name)
      return nil if normalized_song_name.blank?

      normalized_artist_name = normalized_artist_name.to_s

      SongMaster.find_by(
        normalized_song_name: normalized_song_name,
        normalized_artist_name: normalized_artist_name
      ) || SongMasterAlias.find_by(
        normalized_song_name: normalized_song_name,
        normalized_artist_name: normalized_artist_name
      )&.song_master
    end

    # 曲名・アーティスト名から正規化キーと表示名を組み立てて返す。
    # 曲名が空等で正規化キーが作れない場合はnil。
    # 曲名からのアーティスト/注記の分解可否判定のために、既存データとの照合(既定ではSongMasterの検索)を
    # 行うため、完全なread-onlyだが参照系のDBアクセスが発生しうる。
    def self.identity_for(song_name:, artist_name:, artist_corroboration: DEFAULT_ARTIST_CORROBORATION)
      new(song_name, artist_name, artist_corroboration: artist_corroboration).identity
    end

    def initialize(song_name, artist_name, artist_corroboration: DEFAULT_ARTIST_CORROBORATION)
      @song_name = song_name
      @artist_name = artist_name
      @artist_corroboration = artist_corroboration
    end

    def call
      identity = self.identity
      return nil if identity.nil?

      find_or_create(
        identity.normalized_song_name,
        identity.normalized_artist_name,
        identity.song_name,
        identity.artist_name
      )
    end

    def identity
      return nil if @song_name.blank?

      song_name, artist_name = decompose

      normalized_song_name = self.class.normalize(song_name)
      return nil if normalized_song_name.blank?

      Identity.new(
        normalized_song_name: normalized_song_name,
        normalized_artist_name: self.class.normalize(artist_name),
        song_name: song_name.to_s.strip,
        artist_name: artist_name.to_s.strip.presence
      )
    end

    # 曲名が「曲名（xxx）」形式のときに構造だけを見て [曲名, xxx] に分解する(判定はしない)。
    # 形式に一致しない・曲名/括弧内が空になる場合はnil。
    # 例: "マリーゴールド（あいみょん）" -> ["マリーゴールド", "あいみょん"]
    def self.parse_embedded_artist(song_name)
      match = song_name.to_s.strip.match(EMBEDDED_ARTIST_PATTERN)
      return nil if match.nil?

      title = match[:title].strip
      embedded_artist = match[:artist].strip
      return nil if title.blank? || embedded_artist.blank?

      [title, embedded_artist]
    end

    # 括弧内文字列が告知・募集・キー/バージョン等の付随情報に見えるか(アーティスト名らしくないか)。
    def self.announcement_like?(text)
      ANNOUNCEMENT_PATTERN.match?(text.to_s.unicode_normalize(:nfkc).downcase)
    end

    # 曲名先頭の注記(【...】(...)等)を1つ以上剥がした文字列を返す。先頭に注記が無ければそのまま。
    # 例: "【Key+4】あいみょん - マリーゴールド" -> "あいみょん - マリーゴールド"
    def self.strip_leading_annotations(text)
      text.to_s.strip.sub(LEADING_ANNOTATION_PATTERN, "").strip
    end

    # 区切り文字(ハイフン/ダッシュ/スラッシュ)で構造分解した [左, 右] の組を返す(向きの判定はしない)。
    # 複数の区切りがある場合は「最初の区切りで割る」「最後の区切りで割る」の両方を候補にする。
    # 区切りが無ければ空配列。
    def self.separator_splits(text)
      source = text.to_s
      offsets = []
      source.to_enum(:scan, SEPARATOR_PATTERN).each { offsets << Regexp.last_match.offset(0) }
      return [] if offsets.empty?

      [offsets.first, offsets.last].uniq.filter_map do |start_index, end_index|
        left = source[0...start_index].to_s.strip
        right = source[end_index..].to_s.strip
        [left, right] if left.present? && right.present?
      end.uniq
    end

    # NFKC正規化(全角/半角ゆれ・全角スペースを吸収) + 引用符/アポストロフィのASCII統一 +
    # 小文字化 + 空白除去(前後・連続・途中を問わずすべて除去)。
    #
    # 「丸の内/丸ノ内」「略称/正式名称」「feat.表記の有無」「同名異曲」「邦題/原題」
    # 「読み仮名による一致」のような意味的な表記ゆれは、誤統合のリスクがあるため
    # 意図的に対象外(自動では同一視しない)。
    # 例: "Ａmazing Grace" と "amazing grace" を同一キーとして扱う。
    def self.normalize(value)
      value.to_s.unicode_normalize(:nfkc).gsub(QUOTE_NORMALIZATION_PATTERN, QUOTE_NORMALIZATION_MAP).downcase.gsub(/[[:space:]]+/, "")
    end

    private

    # 曲名(と入力済みならアーティスト名欄)から、identity計算に使う [曲名, アーティスト名] を返す。
    #
    # 方針: 曲名の文字列だけを見てアーティスト名や注記を「推測で」切り出さない。
    #   - アーティスト名欄が入力済みなら、その値を尊重し文字列分解で上書きしない。
    #     (先頭注記だけは、剥がした候補が裏付け照合に通る場合に限り除外する)
    #   - アーティスト名欄が空なら、構造的に成立しうる [曲名, アーティスト] の解釈をすべて列挙し、
    #     「裏付け照合(artist_corroboration)に通る」ものだけに絞る。
    #     通る解釈がちょうど1つ(正規化キーが一意)のときだけ、それを採用する。
    #     0個・複数(両向き成立等)なら分解せず、元の文字列をそのまま曲名として扱う。
    def decompose
      raw = @song_name.to_s.strip

      if @artist_name.to_s.strip.present?
        stripped = self.class.strip_leading_annotations(raw)
        if stripped.present? && stripped != raw &&
           corroborated?(self.class.normalize(stripped), self.class.normalize(@artist_name))
          return [stripped, @artist_name]
        end

        return [raw, @artist_name]
      end

      interpretations = candidate_interpretations(raw)
        .reject { |title, artist| title.blank? || artist.blank? }
        .uniq { |title, artist| [self.class.normalize(title), self.class.normalize(artist)] }

      corroborated = interpretations.select do |title, artist|
        corroborated?(self.class.normalize(title), self.class.normalize(artist))
      end
      distinct_keys = corroborated.map { |title, artist| [self.class.normalize(title), self.class.normalize(artist)] }.uniq
      return [raw, @artist_name] unless distinct_keys.size == 1

      corroborated.first
    end

    # 構造的に成立しうる [曲名候補, アーティスト候補] をすべて列挙する(判定はしない)。
    # 元の文字列と、先頭注記を剥がした文字列の両方を起点に、末尾括弧・鉤括弧・区切りを解釈する。
    def candidate_interpretations(raw)
      bases = [raw]
      stripped = self.class.strip_leading_annotations(raw)
      bases << stripped if stripped.present? && stripped != raw

      bases.flat_map { |base| interpretations_for_base(base) }
    end

    def interpretations_for_base(base)
      results = []

      if (parsed = self.class.parse_embedded_artist(base))
        title, embedded_artist = parsed
        results << [title, embedded_artist] unless self.class.announcement_like?(embedded_artist)
      end

      if (match = base.match(BRACKET_TITLE_PATTERN))
        before = match[:before].strip
        inside = match[:inside].strip
        results << [inside, before]
        results << [before, inside]
      end

      self.class.separator_splits(base).each do |left, right|
        results << [left, right]
        results << [right, left]
      end

      results
    end

    def corroborated?(normalized_song_name, normalized_artist_name)
      return false if normalized_song_name.blank? || normalized_artist_name.blank?

      @artist_corroboration.call(
        normalized_song_name: normalized_song_name,
        normalized_artist_name: normalized_artist_name
      )
    end

    def find_or_create(normalized_song_name, normalized_artist_name, display_song_name, display_artist_name, attempt: 0)
      # 完全一致するSongMaster、無ければ統合済みの旧キー(SongMasterAlias)経由の正SongMasterを使う。
      # どちらも無いときだけ新規作成する(統合で削除された旧キーで分裂SongMasterを作り直さない)。
      existing = self.class.existing_master_for(normalized_song_name, normalized_artist_name)
      return existing if existing

      SongMaster.find_or_create_by!(
        normalized_song_name: normalized_song_name,
        normalized_artist_name: normalized_artist_name
      ) do |master|
        master.song_name = display_song_name.to_s.strip
        master.artist_name = display_artist_name.to_s.strip.presence
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # find_or_create_by!の内部find/create間で競合した場合の再試行。
      raise if attempt >= 2

      find_or_create(normalized_song_name, normalized_artist_name, display_song_name, display_artist_name, attempt: attempt + 1)
    end
  end
end
