require "rails_helper"

RSpec.describe ChatMessagesHelper, type: :helper do
  let(:customer) { FactoryBot.create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:chat_message) do
    FactoryBot.create(:chat_message, customer: customer, chat_room: chat_room, content: "**bold**")
  end

  describe "#chat_markdown" do
    it "Chat::MarkdownRenderer に本文を委譲してHTMLを返すこと" do
      expect(helper.chat_markdown(chat_message)).to include("<strong>bold</strong>")
    end

    it "cache_key_with_version をキーにレンダリング結果をキャッシュすること" do
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      begin
        expect(Chat::MarkdownRenderer).to receive(:call).once.and_call_original

        2.times { helper.chat_markdown(chat_message) }
      ensure
        Rails.cache = original_cache
      end
    end
  end

  describe "#chat_reply_excerpt" do
    it "プレーンテキストのまま短ければそのまま返すこと" do
      message = create(:chat_message, customer: customer, chat_room: chat_room, content: "こんにちは")
      expect(helper.chat_reply_excerpt(message)).to eq "こんにちは"
    end

    it "Markdownの太字・斜体・コード記法を除去すること" do
      message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                                   content: "**太字** *斜体* `コード`")
      expect(helper.chat_reply_excerpt(message)).to eq "太字 斜体 コード"
    end

    it "見出し・引用・リストの記法を除去すること" do
      message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                                   content: "# 見出し\n> 引用\n- 箇条書き")
      expect(helper.chat_reply_excerpt(message)).to eq "見出し 引用 箇条書き"
    end

    it "リンク記法はリンクテキストだけに変換すること" do
      message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                                   content: "[公式サイト](https://example.com)")
      expect(helper.chat_reply_excerpt(message)).to eq "公式サイト"
    end

    it "メンション記法は@表示名に変換すること" do
      message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                                   content: "[@トモキ](customer:#{customer.id}) こんにちは")
      expect(helper.chat_reply_excerpt(message)).to eq "@トモキ こんにちは"
    end

    it "改行をスペースへ変換すること" do
      message = create(:chat_message, customer: customer, chat_room: chat_room, content: "1行目\n2行目\n3行目")
      expect(helper.chat_reply_excerpt(message)).to eq "1行目 2行目 3行目"
    end

    it "長すぎる本文は60文字程度で省略すること" do
      long_content = "あ" * 200
      message = create(:chat_message, customer: customer, chat_room: chat_room, content: long_content)
      excerpt = helper.chat_reply_excerpt(message)
      expect(excerpt.length).to be <= 63 # truncateの省略記号("...")分の余裕
      expect(excerpt).to end_with("...")
    end

    it "本文が無く画像のみの場合は「画像」を返すこと" do
      message = build(:chat_message, customer: customer, chat_room: chat_room, content: nil)
      message.attachments.attach(
        io: StringIO.new("dummy"), filename: "test.png", content_type: "image/png"
      )
      message.save!
      expect(helper.chat_reply_excerpt(message)).to eq "画像"
    end

    it "本文が無くPDFのみの場合は「PDFファイル」を返すこと" do
      message = build(:chat_message, customer: customer, chat_room: chat_room, content: nil)
      message.attachments.attach(
        io: StringIO.new("dummy"), filename: "test.pdf", content_type: "application/pdf"
      )
      message.save!
      expect(helper.chat_reply_excerpt(message)).to eq "PDFファイル"
    end

    it "本文もスタンプも添付も無い場合は空文字を返すこと" do
      message = build(:chat_message, customer: customer, chat_room: chat_room, content: nil)
      expect(helper.chat_reply_excerpt(message)).to eq ""
    end

    it "本文が無くスタンプのみの場合はスタンプラベルを返すこと" do
      message = build(:chat_message, customer: customer, chat_room: chat_room, content: nil, stamp_type: "fire")
      expect(helper.chat_reply_excerpt(message)).to eq message.stamp_label
    end

    it "スクリプトタグを含む本文はプレーンテキストのまま返し、Hamlの通常出力(=)でエスケープされること" do
      message = create(:chat_message, customer: customer, chat_room: chat_room, content: "<script>alert(1)</script>こんにちは")
      excerpt = helper.chat_reply_excerpt(message)

      expect(excerpt).to include("<script>")
      expect(helper.content_tag(:div, excerpt)).not_to include("<script>alert")
      expect(helper.content_tag(:div, excerpt)).to include("&lt;script&gt;")
    end
  end
end
