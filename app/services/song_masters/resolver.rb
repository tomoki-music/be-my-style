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
    # 組み合わせを裏付ける既存データが無い場合は分解しない(embedded_artist_split参照)。
    EMBEDDED_ARTIST_PATTERN = /\A(?<title>.+?)[[:space:]]*[(（](?<artist>[^()（）]+)[)）][[:space:]]*\z/

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
    # 裏付けがあるかどうかを返すデフォルト実装。括弧内アーティストの切り出し可否判定に使う。
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

      SongMaster.find_by(
        normalized_song_name: identity.normalized_song_name,
        normalized_artist_name: identity.normalized_artist_name
      )
    end

    # 曲名・アーティスト名から正規化キーと表示名を組み立てて返す。
    # 曲名が空等で正規化キーが作れない場合はnil。
    # 括弧内アーティストの切り出し可否判定のために、既存データとの照合(既定ではSongMasterの検索)を
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

      song_name, artist_name = embedded_artist_split

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

    # アーティスト名欄が空で、曲名が「曲名（アーティスト名）」形式のとき、
    # 次の条件をすべて満たす場合だけ括弧内をアーティスト名として切り出して [曲名, アーティスト名] を返す。
    #   1. アーティスト名欄が未入力(入力済みなら括弧は分解せず既存の値を尊重する)
    #   2. 括弧内が告知・募集・キー・バージョン等の付随情報でない(announcement_like?)
    #   3. 「曲名」+「そのアーティスト名」の組み合わせを裏付ける既存データがある
    #      (既定では同じ正規化キーのSongMasterが存在すること。backfillは未反映のSong情報も含めて判定)
    # いずれかを満たさない曖昧なケースでは分解せず、括弧込みの曲名をそのまま1曲として扱う(安全側)。
    def embedded_artist_split
      return [@song_name, @artist_name] if @artist_name.to_s.strip.present?

      parsed = self.class.parse_embedded_artist(@song_name)
      return [@song_name, @artist_name] if parsed.nil?

      title, embedded_artist = parsed
      return [@song_name, @artist_name] if self.class.announcement_like?(embedded_artist)

      normalized_title = self.class.normalize(title)
      normalized_artist = self.class.normalize(embedded_artist)
      return [@song_name, @artist_name] if normalized_title.blank? || normalized_artist.blank?

      corroborated = @artist_corroboration.call(
        normalized_song_name: normalized_title,
        normalized_artist_name: normalized_artist
      )
      return [@song_name, @artist_name] unless corroborated

      [title, embedded_artist]
    end

    def find_or_create(normalized_song_name, normalized_artist_name, display_song_name, display_artist_name, attempt: 0)
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
