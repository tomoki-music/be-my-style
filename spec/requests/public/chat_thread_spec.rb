require "rails_helper"

RSpec.describe "スレッド機能(Phase3)のテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }

  before do
    create(:chat_room_customer, chat_room: chat_room, customer: customer)
    create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
  end

  describe "GET thread(スレッド取得)" do
    context "DMの場合" do
      before { sign_in customer }

      it "スレッドの親と返信一覧を含むHTMLを200で返すこと" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "9月のセッション曲を決めましょう！")
        reply = create(:chat_message, customer: customer, chat_room: chat_room, content: "私はこの曲がいいです！",
                                       reply_to_chat_message: root)

        get thread_public_chat_message_path(root)

        expect(response).to have_http_status(200)
        expect(response.body).to include("9月のセッション曲を決めましょう！")
        expect(response.body).to include("私はこの曲がいいです！")
        expect(response.body).to include("1件の返信")
        expect(response.body).to match(/data-chat-message-id=['"]#{reply.id}['"]/)
      end

      it "返信メッセージのIDを指定しても、そのスレッドの親を基準に表示すること" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
        reply = create(:chat_message, customer: customer, chat_room: chat_room, content: "返信です",
                                       reply_to_chat_message: root)

        get thread_public_chat_message_path(reply)

        expect(response).to have_http_status(200)
        expect(response.body).to include("元の投稿")
      end

      it "存在しないIDの場合は404を返すこと" do
        get thread_public_chat_message_path(id: 999_999)
        expect(response).to have_http_status(:not_found)
      end

      it "削除済み(スレッド親が削除された)メッセージIDの場合は404を返すこと" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
        root_id = root.id
        root.destroy

        get thread_public_chat_message_path(id: root_id)
        expect(response).to have_http_status(:not_found)
      end

      it "他人のDMスレッドは取得できないこと" do
        stranger = create(:customer)
        other_room = create(:chat_room)
        create(:chat_room_customer, chat_room: other_room, customer: other_customer)
        root = create(:chat_message, customer: other_customer, chat_room: other_room, content: "別DMの投稿")

        sign_out customer
        sign_in stranger
        get thread_public_chat_message_path(root)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "コミュニティの場合" do
      let(:community) { create(:community) }
      let(:member) { create(:customer) }

      before do
        create(:chat_room_customer, chat_room: chat_room, customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: member, community: community)
        sign_in customer
      end

      it "コミュニティメンバーであればスレッドを取得できること" do
        root = create(:chat_message, customer: member, chat_room: chat_room, community: community, content: "元の投稿")
        create(:chat_message, customer: customer, chat_room: chat_room, community: community,
                              content: "了解です", reply_to_chat_message: root)

        get thread_public_chat_message_path(root)
        expect(response).to have_http_status(200)
        expect(response.body).to include("了解です")
      end

      it "未参加コミュニティのスレッドは取得できないこと" do
        non_member = create(:customer)
        root = create(:chat_message, customer: member, chat_room: chat_room, community: community, content: "元の投稿")

        sign_out customer
        sign_in non_member
        get thread_public_chat_message_path(root)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "非ログイン" do
      it "302でログイン画面へリダイレクトされること" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
        get thread_public_chat_message_path(root)
        expect(response).to have_http_status(302)
      end
    end
  end

  describe "POST thread_reply(スレッドへの返信投稿)" do
    context "DMの場合" do
      before { sign_in customer }

      it "スレッド親を基準にreply_to_chat_message_idが保存され、JSONでHTMLと件数が返ること" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")

        expect do
          post thread_reply_public_chat_message_path(root), params: { chat_message: { content: "スレッド返信です" } }
        end.to change(ChatMessage, :count).by(1)

        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        expect(json["replies_count"]).to eq 1
        expect(json["root_message_id"]).to eq root.id
        expect(json["html"]).to include("スレッド返信です")
        expect(ChatMessage.last.reply_to_chat_message_id).to eq root.id
      end

      it "返信メッセージのIDを指定して投稿しても、スレッド親へ正規化されること" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
        reply = create(:chat_message, customer: customer, chat_room: chat_room, content: "1件目の返信",
                                       reply_to_chat_message: root)

        post thread_reply_public_chat_message_path(reply), params: { chat_message: { content: "2件目の返信" } }

        expect(ChatMessage.last.reply_to_chat_message_id).to eq root.id
      end

      it "本文が空の場合はunprocessable_entityとエラーを返すこと" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")

        expect do
          post thread_reply_public_chat_message_path(root), params: { chat_message: { content: "" } }
        end.not_to change(ChatMessage, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"]).to be_present
      end

      it "スレッド親の投稿者へreply_dm通知が作成されること(自分自身の投稿への返信を除く)" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")

        post thread_reply_public_chat_message_path(root), params: { chat_message: { content: "スレッド返信です" } }

        expect(Notification.where(action: "reply_dm", visited_id: other_customer.id).count).to eq 1
      end

      it "自分自身の投稿へのスレッド返信では通知が作成されないこと" do
        root = create(:chat_message, customer: customer, chat_room: chat_room, content: "自分の投稿")

        post thread_reply_public_chat_message_path(root), params: { chat_message: { content: "自己レス" } }

        expect(Notification.where(action: "reply_dm").count).to eq 0
      end

      it "メンション付きのスレッド返信で、返信通知との重複するメンション通知は作成されないこと" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")

        expect do
          post thread_reply_public_chat_message_path(root), params: {
            chat_message: { content: "[@相手](customer:#{other_customer.id}) 了解です" }
          }
        end.to change(ChatMention, :count).by(1)

        expect(Notification.where(action: "reply_dm", visited_id: other_customer.id).count).to eq 1
        expect(Notification.where(action: "mention_dm", visited_id: other_customer.id).count).to eq 0
      end

      it "別のDMのメッセージへは投稿できないこと" do
        stranger = create(:customer)
        other_room = create(:chat_room)
        create(:chat_room_customer, chat_room: other_room, customer: other_customer)
        foreign_root = create(:chat_message, customer: other_customer, chat_room: other_room, content: "別DMの投稿")

        sign_out customer
        sign_in stranger
        expect do
          post thread_reply_public_chat_message_path(foreign_root), params: { chat_message: { content: "不正な投稿" } }
        end.not_to change(ChatMessage, :count)
        expect(response).to have_http_status(:forbidden)
      end

      it "存在しない親IDの場合は404を返すこと" do
        post thread_reply_public_chat_message_path(id: 999_999), params: { chat_message: { content: "投稿" } }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "コミュニティの場合" do
      let(:community) { create(:community) }
      let(:member) { create(:customer) }

      before do
        create(:chat_room_customer, chat_room: chat_room, customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: member, community: community)
        sign_in customer
      end

      it "コミュニティメンバーであればスレッドへ投稿できること" do
        root = create(:chat_message, customer: member, chat_room: chat_room, community: community, content: "元の投稿")

        expect do
          post thread_reply_public_chat_message_path(root), params: { chat_message: { content: "了解です" } }
        end.to change(ChatMessage, :count).by(1)

        expect(ChatMessage.last.community_id).to eq community.id
        expect(ChatMessage.last.reply_to_chat_message_id).to eq root.id
      end

      it "未参加コミュニティのメッセージへは投稿できないこと" do
        non_member = create(:customer)
        root = create(:chat_message, customer: member, chat_room: chat_room, community: community, content: "元の投稿")

        sign_out customer
        sign_in non_member
        expect do
          post thread_reply_public_chat_message_path(root), params: { chat_message: { content: "不正な投稿" } }
        end.not_to change(ChatMessage, :count)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "非ログイン" do
      it "302でログイン画面へリダイレクトされること" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
        post thread_reply_public_chat_message_path(root), params: { chat_message: { content: "投稿" } }
        expect(response).to have_http_status(302)
      end
    end
  end

  describe "スレッド内添付画像の表示(サイズ調整)" do
    before { sign_in customer }

    def attach_sample_image(chat_message)
      chat_message.attachments.attach(
        io: File.open(Rails.root.join("spec/fixtures/11megabytes_sample.png")),
        filename: "sample.png",
        content_type: "image/png"
      )
    end

    it "スレッド内の添付画像にはスレッド専用クラスが付き、クリックで拡大表示できるリンクになっていること" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "画像を送ります")
      attach_sample_image(root)

      get thread_public_chat_message_path(root)

      expect(response).to have_http_status(200)
      expect(response.body).to include("message-image--thread")
      expect(response.body).to include("message-attachments--thread")
      expect(response.body).to match(/<a\b[^>]*class="chat-image-link chat-image-link--thread"[^>]*>/)
      expect(response.body).to match(/<a\b[^>]*target="_blank"[^>]*>/)
    end

    it "通常一覧の添付画像にはスレッド専用クラスが付かないこと" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "画像を送ります")
      attach_sample_image(root)

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(response).to have_http_status(200)
      expect(response.body).not_to include("message-attachments--thread")
      expect(response.body).to include("message-image")
      expect(response.body).not_to include("message-image--thread")
    end

    it "複数の添付画像が1つのスレッド用flexコンテナにまとまって並ぶこと" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "画像を2枚送ります")
      root.attachments.attach(
        [
          { io: File.open(Rails.root.join("spec/fixtures/11megabytes_sample.png")), filename: "sample1.png", content_type: "image/png" },
          { io: File.open(Rails.root.join("spec/fixtures/11megabytes_sample.png")), filename: "sample2.png", content_type: "image/png" }
        ]
      )

      get thread_public_chat_message_path(root)

      expect(response).to have_http_status(200)
      expect(response.body.scan("message-attachments--thread").size).to eq 1
      expect(response.body.scan("message-image--thread").size).to eq 2
    end

    it "スレッド内のMarkdown本文に埋め込まれた画像(![alt](url)記法)にもスレッド専用クラスが付くこと" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room,
                                    content: "見てください ![サンプル](https://example.com/sample.png)",
                                    content_format: :markdown)

      get thread_public_chat_message_path(root)

      expect(response).to have_http_status(200)
      expect(response.body).to include("markdown-body--thread")
      expect(response.body).to match(/<img src="https:\/\/example\.com\/sample\.png" alt="サンプル">/)
    end

    it "通常一覧のMarkdown画像にはスレッド専用クラスが付かないこと" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room,
                                    content: "見てください ![サンプル](https://example.com/sample.png)",
                                    content_format: :markdown)

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(response).to have_http_status(200)
      expect(response.body).to include("markdown-body")
      expect(response.body).not_to include("markdown-body--thread")
    end

  end

  describe "通常一覧には親メッセージのみ表示されること" do
    before { sign_in customer }

    it "DMの一覧に返信メッセージが表示されず、親メッセージのみ表示されること" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿です")
      create(:chat_message, customer: customer, chat_room: chat_room, content: "スレッド内の返信です",
                             reply_to_chat_message: root)

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(response.body).to include("元の投稿です")
      expect(response.body).not_to include("スレッド内の返信です")
      expect(response.body).to include("1件の返信")
    end
  end
end
