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
    def self.call(song_name:, artist_name:)
      new(song_name, artist_name).call
    end

    def initialize(song_name, artist_name)
      @song_name = song_name
      @artist_name = artist_name
    end

    def call
      return nil if @song_name.blank?

      normalized_song_name = self.class.normalize(@song_name)
      return nil if normalized_song_name.blank?

      normalized_artist_name = self.class.normalize(@artist_name)

      find_or_create(normalized_song_name, normalized_artist_name)
    end

    # NFKC正規化 + 小文字化 + 空白除去。
    # 例: "Ａmazing Grace" と "amazing grace" を同一キーとして扱う。
    def self.normalize(value)
      value.to_s.unicode_normalize(:nfkc).downcase.gsub(/[[:space:]]+/, "")
    end

    private

    def find_or_create(normalized_song_name, normalized_artist_name, attempt: 0)
      SongMaster.find_or_create_by!(
        normalized_song_name: normalized_song_name,
        normalized_artist_name: normalized_artist_name
      ) do |master|
        master.song_name = @song_name.to_s.strip
        master.artist_name = @artist_name.to_s.strip.presence
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # find_or_create_by!の内部find/create間で競合した場合の再試行。
      raise if attempt >= 2

      find_or_create(normalized_song_name, normalized_artist_name, attempt: attempt + 1)
    end
  end
end
