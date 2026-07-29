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

  describe "#mention_html_for_request" do
    it "valid_customer_idsに含まれるメンションを.chat-mentionへ変換すること" do
      request = build(:request, request: "[@太郎](customer:5)お願いします")

      html = helper.mention_html_for_request(request, [5])

      expect(html).to include('<span class="chat-mention" data-customer-id="5">@太郎</span>')
    end

    it "本文中の生HTMLはエスケープされ、YouTubeカードと共存すること" do
      request = build(:request, request: "<b>注目</b> https://www.youtube.com/watch?v=abcdefghijk")

      html = helper.mention_html_for_request(request, [])

      expect(html).not_to include("<b>")
      expect(helper.youtube_card_for_request(request)).not_to be_nil
    end
  end
end
