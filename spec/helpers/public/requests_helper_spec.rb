require "rails_helper"

RSpec.describe Public::RequestsHelper, type: :helper do
  describe "#youtube_card_for_request" do
    it "requestが空の場合はnilを返すこと" do
      request = build(:request, request: nil)

      expect(helper.youtube_card_for_request(request)).to be_nil
    end

    it "本文にYouTube URLを含まない場合はnilを返すこと" do
      request = build(:request, request: "オリジナル曲を１曲お願いします！")

      expect(helper.youtube_card_for_request(request)).to be_nil
    end

    it "本文に有効なYouTube URLが含まれる場合はサムネイル付きカードを返すこと" do
      customer = build(:customer, name: "テスト太郎")
      request = build(:request, customer: customer,
                                 request: "この曲でお願いします！ https://www.youtube.com/watch?v=abcdefghijk")

      card = helper.youtube_card_for_request(request)

      expect(card.thumbnail_url).to eq("https://img.youtube.com/vi/abcdefghijk/hqdefault.jpg")
      expect(card.video_url).to eq("https://www.youtube.com/watch?v=abcdefghijk")
      expect(card.title).to eq("YouTubeで動画を見る")
      expect(card.author_name).to eq("テスト太郎")
    end

    it "youtu.be形式のURLでもカードを返すこと" do
      request = build(:request, request: "https://youtu.be/abcdefghijk?feature=shared")

      card = helper.youtube_card_for_request(request)

      expect(card.thumbnail_url).to eq("https://img.youtube.com/vi/abcdefghijk/hqdefault.jpg")
    end

    it "未対応ホストのURLの場合はnilを返すこと" do
      request = build(:request, request: "https://example.com/watch?v=abcdefghijk")

      expect(helper.youtube_card_for_request(request)).to be_nil
    end

    it "不正なURL文字列でも例外にならずnilを返すこと" do
      request = build(:request, request: "javascript:alert(1)")

      expect(helper.youtube_card_for_request(request)).to be_nil
    end
  end
end
