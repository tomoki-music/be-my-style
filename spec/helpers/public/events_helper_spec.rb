require "rails_helper"

RSpec.describe Public::EventsHelper, type: :helper do
  describe "#youtube_card_for" do
    it "youtube_urlが空の場合はnilを返すこと" do
      song = build(:song, youtube_url: nil)

      expect(helper.youtube_card_for(song)).to be_nil
    end

    it "youtube_urlが未対応形式の場合はnilを返すこと" do
      song = build(:song, youtube_url: "https://example.com/not-youtube")

      expect(helper.youtube_card_for(song)).to be_nil
    end

    it "有効なYouTube URLの場合はサムネイル・タイトル・アーティスト名を含むデータを返すこと" do
      song = build(:song, song_name: "丸の内サディスティック", artist_name: "椎名林檎",
                           youtube_url: "https://www.youtube.com/watch?v=abcdefghijk")

      card = helper.youtube_card_for(song)

      expect(card.thumbnail_url).to eq("https://img.youtube.com/vi/abcdefghijk/hqdefault.jpg")
      expect(card.video_url).to eq("https://www.youtube.com/watch?v=abcdefghijk")
      expect(card.title).to eq("丸の内サディスティック")
      expect(card.author_name).to eq("椎名林檎")
    end

    it "アーティスト名が未設定でもnilを返さないこと" do
      song = build(:song, song_name: "曲名のみ", artist_name: nil,
                           youtube_url: "https://youtu.be/abcdefghijk")

      card = helper.youtube_card_for(song)

      expect(card.title).to eq("曲名のみ")
      expect(card.author_name).to be_nil
    end
  end

  describe "_youtube_card partial" do
    it "カードが存在する場合はサムネイル・タイトル・外部リンク属性を出力すること" do
      song = build(:song, song_name: "<script>alert(1)</script>", artist_name: "テスト",
                           youtube_url: "https://youtu.be/abcdefghijk")
      card = helper.youtube_card_for(song)

      html = render partial: "public/events/youtube_card", locals: { card: card }

      expect(html).to include("img.youtube.com/vi/abcdefghijk/hqdefault.jpg")
      expect(html).to include("target='_blank'")
      expect(html).to include("rel='noopener noreferrer'")
      expect(html).not_to include("<script>alert(1)</script>")
      expect(html).to include("&lt;script&gt;")
    end

    it "cardがnilの場合は何も出力しないこと" do
      html = render partial: "public/events/youtube_card", locals: { card: nil }

      expect(html.strip).to eq("")
    end
  end
end
