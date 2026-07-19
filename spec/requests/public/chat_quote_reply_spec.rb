require "rails_helper"

RSpec.describe "引用返信の表示のテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }

  before do
    create(:chat_room_customer, chat_room: chat_room, customer: customer)
    create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
    sign_in customer
  end

  describe "通常一覧の引用カード表示" do
    it "引用返信メッセージに、引用元の投稿者名・本文抜粋を含む引用カードが表示されること" do
      original = create(:chat_message, customer: other_customer, chat_room: chat_room,
                                        content: "次回のセッション曲を決めましょう")
      create(:chat_message, customer: customer, chat_room: chat_room,
                            content: "了解です", quoted_chat_message: original)

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(response).to have_http_status(200)
      expect(response.body).to include("quote-card")
      expect(response.body).to include(other_customer.name)
      expect(response.body).to include("次回のセッション曲を決めましょう")
      expect(response.body).to match(/data-quote-target-id=['"]chat-message-#{original.id}['"]/)
    end

    it "引用元が画像のみの場合、引用カードにサムネイルが表示されること" do
      original = build(:chat_message, customer: other_customer, chat_room: chat_room, content: nil)
      original.attachments.attach(
        io: File.open(Rails.root.join("spec/fixtures/11megabytes_sample.png")),
        filename: "sample.png",
        content_type: "image/png"
      )
      original.save!
      create(:chat_message, customer: customer, chat_room: chat_room,
                            content: "見ました", quoted_chat_message: original)

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(response.body).to include("quote-card-thumbnail")
    end

    it "引用元メッセージが削除された場合、quoted_chat_message_idがnullifyされ引用カードが表示されないこと" do
      original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
      quote_reply = create(:chat_message, customer: customer, chat_room: chat_room,
                                          content: "了解です", quoted_chat_message: original)
      original.destroy

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(response).to have_http_status(200)
      expect(response.body).to include("了解です")
      expect(quote_reply.reload.quoted_chat_message_id).to be_nil
      expect(response.body).not_to include("quote-card-author")
    end

    it "引用元も引用先も、通常のMarkdown本文としてお互い独立してレンダリングされること(本文コピーをしない)" do
      # 引用元(original)自身は通常のスレッドrootとしても一覧に表示され、そちらは
      # Markdownとして正しく展開される。引用カード側(.quote-card-snippet)だけが
      # プレーンテキスト化されていることを確認するため、要素を絞り込んで検証する。
      original = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room,
                                                    content: "**強調された元の投稿**")
      create(:chat_message, customer: customer, chat_room: chat_room,
                            content: "了解です", quoted_chat_message: original)

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      doc = Nokogiri::HTML(response.body)
      snippet = doc.at_css(".quote-card-snippet")
      expect(snippet.text).to eq("強調された元の投稿")
      expect(snippet.to_html).not_to include("<strong>")
    end

    it "各メッセージに引用返信ボタンが表示され、本文抜粋等がdata属性に載ること" do
      create(:chat_message, customer: other_customer, chat_room: chat_room, content: "こんにちは")

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(response.body).to include("quote-button")
      expect(response.body).to include("data-quote-label")
      expect(response.body).to include("さんのメッセージを引用")
    end
  end

  describe "スレッドパネル内の引用カード表示" do
    it "スレッドrootの引用返信をスレッドパネルのHTML断片内で表示できること" do
      quoted = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "引用される投稿")
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
      create(:chat_message, customer: customer, chat_room: chat_room, content: "同意です",
                            reply_to_chat_message: root, quoted_chat_message: quoted)

      get thread_public_chat_message_path(root)

      expect(response).to have_http_status(200)
      expect(response.body).to include("quote-card")
      expect(response.body).to include("引用される投稿")
    end
  end
end
