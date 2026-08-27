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
    EMBEDDED_ARTIST_PATTERN = /\A(?<title>.+?)[[:space:]]*[(（](?<artist>[^()（）]+)[)）][[:space:]]*\z/

    def self.call(song_name:, artist_name:)
      new(song_name, artist_name).call
    end

    def initialize(song_name, artist_name)
      @song_name = song_name
      @artist_name = artist_name
    end

    def call
      return nil if @song_name.blank?

      song_name, artist_name = self.class.split_embedded_artist(@song_name, @artist_name)

      normalized_song_name = self.class.normalize(song_name)
      return nil if normalized_song_name.blank?

      normalized_artist_name = self.class.normalize(artist_name)

      find_or_create(normalized_song_name, normalized_artist_name, song_name, artist_name)
    end

    # アーティスト名欄が空で、曲名が「曲名（アーティスト名）」形式のとき、括弧内をアーティスト名として
    # 切り出した [曲名, アーティスト名] を返す。それ以外(アーティスト名欄が入力済み・括弧が無い・
    # 切り出すと曲名や括弧内が空になる)は [元の曲名, 元のアーティスト名] をそのまま返す。
    # 例: ("マリーゴールド（あいみょん）", nil) -> ["マリーゴールド", "あいみょん"]
    def self.split_embedded_artist(song_name, artist_name)
      return [song_name, artist_name] if artist_name.to_s.strip.present?

      match = song_name.to_s.strip.match(EMBEDDED_ARTIST_PATTERN)
      return [song_name, artist_name] if match.nil?

      title = match[:title].strip
      embedded_artist = match[:artist].strip
      return [song_name, artist_name] if title.blank? || embedded_artist.blank?

      [title, embedded_artist]
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
