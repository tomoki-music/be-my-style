require "rails_helper"

RSpec.describe "メッセージ編集(PATCH update)のテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }

  before do
    create(:chat_room_customer, chat_room: chat_room, customer: customer)
    create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
  end

  describe "正常系" do
    before { sign_in customer }

    it "投稿者本人が通常メッセージの本文を編集できること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前の本文")

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "編集後の本文" } }

      expect(response).to have_http_status(:ok)
      expect(chat_message.reload.content).to eq "編集後の本文"
    end

    it "本文編集でイベントURLを追加すると、レスポンスのhtml(render_to_string)に直後からイベントカードが含まれること" do
      community = create(:community)
      event = create(:event, :event_with_songs, customer: customer, community: community, event_name: "編集直後確認イベント")
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前の本文")

      patch public_chat_message_path(chat_message), params: {
        chat_message: { content: "見て https://www.example.com/public/events/#{event.id}" }
      }

      expect(response).to have_http_status(:ok)
      html = JSON.parse(response.body)["html"]
      expect(html).to include("link-preview-card--event")
      expect(html).to include("編集直後確認イベント")

      preview = chat_message.reload.chat_message_link_previews.first
      expect(preview.provider).to eq "event"
      expect(preview.status).to eq "fetched"
    end

    it "投稿者本人がスレッド返信を編集できること" do
      root = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: "元の投稿")
      reply = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前の返信",
                                     reply_to_chat_message: root)

      patch public_chat_message_path(reply), params: { chat_message: { content: "編集後の返信" } }

      expect(response).to have_http_status(:ok)
      expect(reply.reload.content).to eq "編集後の返信"
      expect(reply.reply_to_chat_message_id).to eq root.id
    end

    it "投稿者本人が引用返信を編集できること" do
      quoted = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: "引用される投稿")
      quote_reply = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前の引用返信",
                                           quoted_chat_message: quoted)

      patch public_chat_message_path(quote_reply), params: { chat_message: { content: "編集後の引用返信" } }

      expect(response).to have_http_status(:ok)
      expect(quote_reply.reload.content).to eq "編集後の引用返信"
      expect(quote_reply.quoted_chat_message_id).to eq quoted.id
    end

    it "DMメッセージを編集できること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前")

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "編集後" } }

      expect(response).to have_http_status(:ok)
      expect(chat_message.reload.content).to eq "編集後"
    end

    context "コミュニティチャットの場合" do
      let(:community) { create(:community) }
      let(:community_chat_room) { create(:chat_room) }

      before do
        create(:chat_room_customer, chat_room: community_chat_room, customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: customer, community: community)
      end

      it "コミュニティメッセージを編集できること" do
        chat_message = create(:chat_message, :markdown, customer: customer, chat_room: community_chat_room,
                                                          community: community, content: "編集前")

        patch public_chat_message_path(chat_message), params: { chat_message: { content: "編集後" } }

        expect(response).to have_http_status(:ok)
        expect(chat_message.reload.content).to eq "編集後"
      end

      it "community_id: nilのLegacyコミュニティメッセージを編集できること" do
        legacy_message = create(:chat_message, :markdown, customer: customer, chat_room: community_chat_room,
                                                            content: "過去の投稿(community_id無し)")
        expect(legacy_message.community_id).to be_nil

        patch public_chat_message_path(legacy_message), params: { chat_message: { content: "編集後のLegacy投稿" } }

        expect(response).to have_http_status(:ok)
        expect(legacy_message.reload.content).to eq "編集後のLegacy投稿"
      end

      it "現在そのコミュニティへの参加権限を失っている場合は編集できないこと(403相当)" do
        chat_message = create(:chat_message, :markdown, customer: customer, chat_room: community_chat_room,
                                                          community: community, content: "編集前")
        CommunityCustomer.where(customer_id: customer.id, community_id: community.id).destroy_all

        patch public_chat_message_path(chat_message), params: { chat_message: { content: "不正な編集" } }

        expect(response).to have_http_status(:forbidden)
        expect(chat_message.reload.content).to eq "編集前"
      end
    end

    it "編集後にedited_atが設定されること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前")
      expect(chat_message.edited_at).to be_nil

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "編集後" } }

      expect(chat_message.reload.edited_at).to be_present
    end

    it "新規投稿時はedited_atがnilのままであること" do
      chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "新規投稿")
      expect(chat_message.edited_at).to be_nil
    end

    it "Markdown投稿を編集してもcontent_formatがmarkdownのまま維持されること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前")

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "編集後" } }

      expect(chat_message.reload.content_format).to eq "markdown"
    end

    it "Legacy plain投稿を編集してもcontent_formatがplainのまま維持されること" do
      chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")
      expect(chat_message.content_format).to eq "plain"

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "編集後" } }

      expect(chat_message.reload.content_format).to eq "plain"
    end

    it "添付画像が編集後も維持されること(blob idが変わらない)" do
      chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "画像を送ります")
      chat_message.attachments.attach(
        io: File.open(Rails.root.join("spec/fixtures/11megabytes_sample.png")),
        filename: "sample.png",
        content_type: "image/png"
      )
      original_blob_ids = chat_message.attachments.map { |a| a.blob.id }

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "編集後の本文" } }

      chat_message.reload
      expect(chat_message.attachments.map { |a| a.blob.id }).to eq original_blob_ids
    end

    it "編集によってreply_to_chat_message_id / quoted_chat_message_id / chat_room / customer / communityが変わらないこと" do
      community = create(:community)
      community_chat_room = create(:chat_room)
      create(:chat_room_customer, chat_room: community_chat_room, customer: customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)

      root = create(:chat_message, :markdown, customer: customer, chat_room: community_chat_room, community: community,
                                    content: "スレッド元")
      quoted = create(:chat_message, :markdown, customer: customer, chat_room: community_chat_room, community: community,
                                      content: "引用される投稿")
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: community_chat_room,
                                            community: community, content: "編集前",
                                            reply_to_chat_message: root, quoted_chat_message: quoted)

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "編集後" } }

      chat_message.reload
      expect(chat_message.reply_to_chat_message_id).to eq root.id
      expect(chat_message.quoted_chat_message_id).to eq quoted.id
      expect(chat_message.chat_room_id).to eq community_chat_room.id
      expect(chat_message.customer_id).to eq customer.id
      expect(chat_message.community_id).to eq community.id
    end

    it "成功時に期待するJSON(chat_message_id, html)が返り、htmlが既存message partialで描画されること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前")

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "編集後の本文です" } }

      json = JSON.parse(response.body)
      expect(json["chat_message_id"]).to eq chat_message.id
      expect(json["html"]).to include("編集後の本文です")
      expect(json["html"]).to match(/data-chat-message-id=['"]#{chat_message.id}['"]/)
    end

    it "引用元メッセージを編集すると、次回描画時に引用カードが最新本文を表示すること(関連参照方式)" do
      original = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                        content: "編集前の元投稿")
      create(:chat_message, customer: other_customer, chat_room: chat_room, content: "了解です", quoted_chat_message: original)

      patch public_chat_message_path(original), params: { chat_message: { content: "編集後の元投稿" } }
      expect(response).to have_http_status(:ok)

      get public_chat_room_path(chat_room, customer_id: other_customer.id)
      expect(response.body).to include("編集後の元投稿")
      expect(response.body).not_to include("編集前の元投稿")
    end

    it "テキスト＋一般ファイル(PDF)は編集成功し、添付が維持されること(blob idが変わらない)" do
      chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "資料を送ります")
      chat_message.attachments.attach(io: StringIO.new("dummy"), filename: "test.pdf", content_type: "application/pdf")
      original_blob_ids = chat_message.attachments.map { |a| a.blob.id }

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "資料を更新しました" } }

      expect(response).to have_http_status(:ok)
      chat_message.reload
      expect(chat_message.content).to eq "資料を更新しました"
      expect(chat_message.attachments.map { |a| a.blob.id }).to eq original_blob_ids
    end

    it "テキスト＋スタンプは編集成功し、stamp_typeが維持されること" do
      chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "いいね",
                                            stamp_type: "fire")

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "いいねです" } }

      expect(response).to have_http_status(:ok)
      chat_message.reload
      expect(chat_message.content).to eq "いいねです"
      expect(chat_message.stamp_type).to eq "fire"
    end
  end

  describe "編集不可なメッセージ種別(添付のみ・スタンプのみ)への直接PATCH" do
    before { sign_in customer }

    it "画像のみのメッセージへPATCHすると403になり、本文が追加されないこと" do
      chat_message = build(:chat_message, customer: customer, chat_room: chat_room, content: nil)
      chat_message.attachments.attach(io: StringIO.new("dummy"), filename: "test.png", content_type: "image/png")
      chat_message.save!

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "後から追加した本文" } }

      expect(response).to have_http_status(:forbidden)
      chat_message.reload
      expect(chat_message.content).to be_nil
      expect(chat_message.edited_at).to be_nil
    end

    it "一般ファイル(PDF)のみのメッセージへPATCHすると403になり、本文が追加されないこと" do
      chat_message = build(:chat_message, customer: customer, chat_room: chat_room, content: nil)
      chat_message.attachments.attach(io: StringIO.new("dummy"), filename: "test.pdf", content_type: "application/pdf")
      chat_message.save!

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "後から追加した本文" } }

      expect(response).to have_http_status(:forbidden)
      chat_message.reload
      expect(chat_message.content).to be_nil
      expect(chat_message.edited_at).to be_nil
    end

    it "スタンプのみのメッセージへPATCHすると403になり、本文が追加されないこと" do
      chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: nil, stamp_type: "fire")

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "後から追加した本文" } }

      expect(response).to have_http_status(:forbidden)
      chat_message.reload
      expect(chat_message.content).to be_nil
      expect(chat_message.stamp_type).to eq "fire"
      expect(chat_message.edited_at).to be_nil
    end

    it "画像のみのメッセージへ空文字でPATCHしても403になること(no-op更新の余地を与えない)" do
      chat_message = build(:chat_message, customer: customer, chat_room: chat_room, content: nil)
      chat_message.attachments.attach(io: StringIO.new("dummy"), filename: "test.png", content_type: "image/png")
      chat_message.save!

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "" } }

      expect(response).to have_http_status(:forbidden)
      expect(chat_message.reload.edited_at).to be_nil
    end

    it "スタンプのみのメッセージへ空文字でPATCHしても403になること(no-op更新の余地を与えない)" do
      chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: nil, stamp_type: "fire")

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "" } }

      expect(response).to have_http_status(:forbidden)
      expect(chat_message.reload.edited_at).to be_nil
    end
  end

  describe "編集ボタンの表示条件(通常一覧)" do
    before { sign_in customer }

    it "本文のあるメッセージには編集ボタンが表示されること" do
      normal = create(:chat_message, customer: customer, chat_room: chat_room, content: "通常メッセージ")

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#chat-message-#{normal.id} .edit-button")).to be_present
    end

    it "画像のみのメッセージには編集ボタンが表示されないこと" do
      image_only = build(:chat_message, customer: customer, chat_room: chat_room, content: nil)
      image_only.attachments.attach(io: StringIO.new("dummy"), filename: "test.png", content_type: "image/png")
      image_only.save!

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#chat-message-#{image_only.id} .edit-button")).to be_nil
    end

    it "スタンプのみのメッセージには編集ボタンが表示されないこと" do
      stamp_only = create(:chat_message, customer: customer, chat_room: chat_room, content: nil, stamp_type: "fire")

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#chat-message-#{stamp_only.id} .edit-button")).to be_nil
    end

    it "テキスト＋添付のメッセージには編集ボタンが表示されること" do
      with_attachment = create(:chat_message, customer: customer, chat_room: chat_room, content: "画像を送ります")
      with_attachment.attachments.attach(io: StringIO.new("dummy"), filename: "test.png", content_type: "image/png")

      get public_chat_room_path(chat_room, customer_id: other_customer.id)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#chat-message-#{with_attachment.id} .edit-button")).to be_present
    end
  end

  # Mention Hydration(編集開始時に内部記法を@usernameへ戻して表示する機能)はView/Frontend側の
  # 処理であり、保存されるcontentの形式(内部記法)自体は変わらない。ここではUpdate側の
  # 回帰確認として、フロント側のbuildSubmissionContentが再構築する内部記法contentを
  # そのままPATCHしてもMentionSyncServiceの既存挙動が壊れないことのみを確認する。
  describe "メンション付きメッセージの編集(Mention Hydration対象)" do
    before { sign_in customer }

    it "内部記法を維持したまま保存するとメンションが維持されること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                            content: "[@相手](customer:#{other_customer.id}) こんにちは")
      Chat::MentionSyncService.call(chat_message)
      expect(chat_message.chat_mentions.count).to eq 1

      patch public_chat_message_path(chat_message),
            params: { chat_message: { content: "[@相手](customer:#{other_customer.id}) こんにちは、元気ですか" } }

      expect(response).to have_http_status(:ok)
      expect(chat_message.reload.content).to eq "[@相手](customer:#{other_customer.id}) こんにちは、元気ですか"
      expect(chat_message.chat_mentions.count).to eq 1
      expect(chat_message.chat_mentions.pluck(:mentioned_customer_id)).to eq [other_customer.id]
    end

    it "同一相手への内部記法が複数回含まれていてもChatMentionが重複しないこと" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前")

      patch public_chat_message_path(chat_message), params: {
        chat_message: {
          content: "[@相手](customer:#{other_customer.id}) さん [@相手](customer:#{other_customer.id}) さん"
        }
      }

      expect(response).to have_http_status(:ok)
      expect(chat_message.reload.chat_mentions.count).to eq 1
    end

    it "編集によりメンションを削除すると同期されること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                            content: "[@相手](customer:#{other_customer.id}) こんにちは")
      Chat::MentionSyncService.call(chat_message)
      expect(chat_message.chat_mentions.count).to eq 1

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "こんにちは" } }

      expect(response).to have_http_status(:ok)
      expect(chat_message.reload.chat_mentions.count).to eq 0
    end

    it "メンション付き編集でもedited_atが更新されること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                            content: "[@相手](customer:#{other_customer.id}) こんにちは")
      expect(chat_message.edited_at).to be_nil

      patch public_chat_message_path(chat_message),
            params: { chat_message: { content: "[@相手](customer:#{other_customer.id}) こんにちは!" } }

      expect(chat_message.reload.edited_at).to be_present
    end
  end

  describe "権限・異常系" do
    it "他人のメッセージを編集できないこと(404相当)" do
      chat_message = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "他人の投稿")
      sign_in customer

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "不正な編集" } }

      expect(response).to have_http_status(:not_found)
      expect(chat_message.reload.content).to eq "他人の投稿"
    end

    it "未ログインユーザーは編集できないこと(302でログイン画面へ)" do
      chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "不正な編集" } }

      expect(response).to have_http_status(302)
      expect(response).to redirect_to("/customers/sign_in")
    end

    it "存在しないメッセージを編集できないこと(404)" do
      sign_in customer

      patch public_chat_message_path(id: 999_999), params: { chat_message: { content: "不正な編集" } }

      expect(response).to have_http_status(:not_found)
    end

    it "投稿者本人でも、現在DMチャットルームへの投稿権限を失っている場合は編集できないこと(403相当)" do
      chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")
      sign_in customer
      ChatRoomCustomer.where(chat_room_id: chat_room.id, customer_id: customer.id, community_id: nil).destroy_all

      patch public_chat_message_path(chat_message), params: { chat_message: { content: "不正な編集" } }

      expect(response).to have_http_status(:forbidden)
      expect(chat_message.reload.content).to eq "編集前"
    end

    context "strong parametersのテスト" do
      before { sign_in customer }

      it "空本文かつstamp・attachmentが無い場合はvalidation errorになり、本文もedited_atも変わらないこと" do
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")

        patch public_chat_message_path(chat_message), params: { chat_message: { content: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(chat_message.reload.content).to eq "編集前"
        expect(chat_message.edited_at).to be_nil
      end

      it "空白文字のみへの更新はvalidation errorになり、本文もedited_atも変わらないこと" do
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")

        patch public_chat_message_path(chat_message), params: { chat_message: { content: "   " } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(chat_message.reload.content).to eq "編集前"
        expect(chat_message.edited_at).to be_nil
      end

      it "不正なcustomer_idを送っても書き換えられないこと" do
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")

        patch public_chat_message_path(chat_message), params: {
          chat_message: { content: "編集後", customer_id: other_customer.id }
        }

        expect(chat_message.reload.customer_id).to eq customer.id
      end

      it "不正なchat_room_idを送っても書き換えられないこと" do
        other_room = create(:chat_room)
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")

        patch public_chat_message_path(chat_message), params: {
          chat_message: { content: "編集後", chat_room_id: other_room.id }
        }

        expect(chat_message.reload.chat_room_id).to eq chat_room.id
      end

      it "不正なcommunity_idを送っても書き換えられないこと" do
        community = create(:community)
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")
        expect(chat_message.community_id).to be_nil

        patch public_chat_message_path(chat_message), params: {
          chat_message: { content: "編集後", community_id: community.id }
        }

        expect(chat_message.reload.community_id).to be_nil
      end

      it "不正なreply_to_chat_message_idを送っても書き換えられないこと" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")

        patch public_chat_message_path(chat_message), params: {
          chat_message: { content: "編集後", reply_to_chat_message_id: root.id }
        }

        expect(chat_message.reload.reply_to_chat_message_id).to be_nil
      end

      it "不正なquoted_chat_message_idを送っても書き換えられないこと" do
        original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")

        patch public_chat_message_path(chat_message), params: {
          chat_message: { content: "編集後", quoted_chat_message_id: original.id }
        }

        expect(chat_message.reload.quoted_chat_message_id).to be_nil
      end

      it "不正なcontent_formatを送っても書き換えられないこと" do
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")
        expect(chat_message.content_format).to eq "plain"

        patch public_chat_message_path(chat_message), params: {
          chat_message: { content: "編集後", content_format: "markdown" }
        }

        expect(chat_message.reload.content_format).to eq "plain"
      end

      it "不正なattachmentsパラメータを送っても添付が変わらないこと" do
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "編集前")
        chat_message.attachments.attach(
          io: File.open(Rails.root.join("spec/fixtures/11megabytes_sample.png")),
          filename: "sample.png",
          content_type: "image/png"
        )
        original_blob_ids = chat_message.attachments.map { |a| a.blob.id }

        patch public_chat_message_path(chat_message), params: {
          chat_message: {
            content: "編集後",
            attachments: [fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "image/png")]
          }
        }

        chat_message.reload
        expect(chat_message.attachments.map { |a| a.blob.id }).to eq original_blob_ids
      end
    end
  end

  describe "Transaction回帰" do
    before { sign_in customer }

    it "MentionSyncServiceで例外が発生した場合、contentとedited_atがロールバックされること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前")
      allow(Chat::MentionSyncService).to receive(:call).and_raise(StandardError, "mention sync boom")

      expect do
        patch public_chat_message_path(chat_message), params: { chat_message: { content: "編集後" } }
      end.to raise_error(StandardError, "mention sync boom")

      expect(chat_message.reload.content).to eq "編集前"
      expect(chat_message.edited_at).to be_nil
    end
  end
end
