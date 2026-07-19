require 'rails_helper'

RSpec.describe "chat_messagesコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let!(:chat_room_customer) { create(:chat_room_customer, customer: other_customer, chat_room: chat_room) }

  describe "ログイン済み" do
    context "createアクションのテスト" do
      before do
        # Chat::ChatRoomAuthorizationにより、投稿者(current_customer)自身もこのchat_roomの
        # 参加者であることが要求されるため、customer自身もchat_room_customerとして登録する
        # (トップレベルのlet!はother_customerしか登録していない)。
        create(:chat_room_customer, chat_room: chat_room, customer: customer)
        sign_in customer
        get public_chat_room_path(chat_room)
        @chat_room = chat_room
      end
      it "メッセージ作成が成功する" do
        expect do
          post public_chat_messages_path, params: {
          chat_message: {
            content: "お元気ですか？",
            chat_room_id: chat_room.id,
            customer_id: 1,
          }
          }
        end.to change(ChatMessage, :count).by(1)
      end
    end
    context "community_createアクションのテスト" do
      let(:community) { create(:community) }
      let(:community_chat_room) { create(:chat_room) }

      before do
        # community_createはコミュニティ参加権限(CommunityCustomer)を要求するため、
        # トップレベルのchat_room(DM用)とは別のコミュニティ専用chat_roomを用意し、
        # customerをそのコミュニティのメンバーとして登録する。
        create(:chat_room_customer, chat_room: community_chat_room, customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: customer, community: community)
        sign_in customer
      end
      it "コミュニティへメッセージ作成が成功する" do
        expect do
          post community_create_public_chat_messages_path, params: {
          chat_message: {
            content: "お元気ですか？",
            chat_room_id: community_chat_room.id,
            customer_id: 1,
          }
          }
        end.to change(ChatMessage, :count).by(1)
      end
    end
    context "非参加者は投稿できないこと(セキュリティ)" do
      before { sign_in customer }

      it "参加していないDMのchat_roomへは投稿できないこと" do
        # トップレベルのlet!はother_customerしか登録しておらず、customerはこのchat_roomの
        # 参加者ではない。
        expect do
          post public_chat_messages_path, params: {
            chat_message: { content: "不正な投稿", chat_room_id: chat_room.id, customer_id: other_customer.id }
          }
        end.not_to change(ChatMessage, :count)
        expect(response).to redirect_to(root_path)
      end

      it "参加していないコミュニティのchat_roomへは投稿できないこと" do
        community = create(:community)
        community_chat_room = create(:chat_room)
        member = create(:customer)
        create(:chat_room_customer, chat_room: community_chat_room, customer: member, community: community)
        CommunityCustomer.find_or_create_by!(customer: member, community: community)

        expect do
          post community_create_public_chat_messages_path, params: {
            chat_message: { content: "不正な投稿", chat_room_id: community_chat_room.id }
          }
        end.not_to change(ChatMessage, :count)
      end
    end

    context "メンション機能のテスト(DM)" do
      before do
        create(:chat_room_customer, chat_room: chat_room, customer: customer)
        sign_in customer
      end

      it "チャットの参加者へのメンションでChatMentionと通知(mention_dm)が作成されること" do
        expect do
          post public_chat_messages_path, params: {
            chat_message: {
              content: "[@相手](customer:#{other_customer.id}) お元気ですか？",
              chat_room_id: chat_room.id,
              customer_id: other_customer.id
            }
          }
        end.to change(ChatMention, :count).by(1)

        mention = ChatMention.last
        expect(mention.mentioned_customer).to eq other_customer
        expect(Notification.where(action: "mention_dm", visited_id: other_customer.id).count).to eq 1
      end

      it "アクセス権のないユーザーへのメンションはChatMentionを作成しないこと" do
        stranger = create(:customer)
        expect do
          post public_chat_messages_path, params: {
            chat_message: {
              content: "[@他人](customer:#{stranger.id}) お元気ですか？",
              chat_room_id: chat_room.id,
              customer_id: other_customer.id
            }
          }
        end.not_to change(ChatMention, :count)
      end

      it "自分自身のIDを含む不正な記法ではChatMentionを作成しないこと" do
        expect do
          post public_chat_messages_path, params: {
            chat_message: {
              content: "[@自分](customer:#{customer.id}) お元気ですか？",
              chat_room_id: chat_room.id,
              customer_id: other_customer.id
            }
          }
        end.not_to change(ChatMention, :count)
      end
    end

    context "メンション機能のテスト(コミュニティ)" do
      let(:community) { create(:community) }
      let(:community_chat_room) { create(:chat_room) }
      let(:member) { create(:customer) }

      before do
        create(:chat_room_customer, chat_room: community_chat_room, customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: member, community: community)
        sign_in customer
      end

      it "コミュニティメンバーへのメンションでChatMentionと通知(mention_community)が作成されること" do
        expect do
          post community_create_public_chat_messages_path, params: {
            chat_message: {
              content: "[@メンバー](customer:#{member.id}) お願いします",
              chat_room_id: community_chat_room.id
            }
          }
        end.to change(ChatMention, :count).by(1)

        expect(ChatMessage.last.community_id).to eq community.id
        notification = Notification.find_by(action: "mention_community", visited_id: member.id)
        expect(notification).to be_present
        expect(notification.community_id).to eq community.id
        expect(notification.chat_message_id).to eq ChatMessage.last.id
      end

      it "コミュニティメンバーでないユーザーへのメンションはChatMentionを作成しないこと" do
        non_member = create(:customer)
        expect do
          post community_create_public_chat_messages_path, params: {
            chat_message: {
              content: "[@非メンバー](customer:#{non_member.id}) お願いします",
              chat_room_id: community_chat_room.id
            }
          }
        end.not_to change(ChatMention, :count)
      end
    end

    context "返信機能のテスト(DM)" do
      before do
        # Chat::ReplyTargetResolverは返信元だけでなく「返信する側(current_customer)」も
        # 対象chat_roomの参加者であることを検証するため、customer自身もchat_room_customerとして登録する
        # (トップレベルのlet!はother_customerしか登録していない)。
        create(:chat_room_customer, chat_room: chat_room, customer: customer)
        sign_in customer
      end

      it "reply_to_chat_message_idを指定せずに通常投稿できること" do
        post public_chat_messages_path, params: {
          chat_message: { content: "お元気ですか？", chat_room_id: chat_room.id, customer_id: other_customer.id }
        }
        expect(ChatMessage.last.reply_to_chat_message_id).to be_nil
      end

      it "同じchat_room内のメッセージへ返信するとreply_to_chat_message_idが保存されること" do
        original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")

        post public_chat_messages_path, params: {
          chat_message: {
            content: "了解しました",
            chat_room_id: chat_room.id,
            customer_id: other_customer.id,
            reply_to_chat_message_id: original.id
          }
        }
        expect(ChatMessage.last.reply_to_chat_message_id).to eq original.id
      end

      it "メンション付きの返信でChatMentionと返信通知(reply_dm)の両方が作成されること" do
        original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")

        expect do
          post public_chat_messages_path, params: {
            chat_message: {
              content: "[@相手](customer:#{other_customer.id}) 了解しました",
              chat_room_id: chat_room.id,
              customer_id: other_customer.id,
              reply_to_chat_message_id: original.id
            }
          }
        end.to change(ChatMention, :count).by(1)

        expect(Notification.where(action: "reply_dm", visited_id: other_customer.id).count).to eq 1
        # 返信先と同じ相手へのメンションは、重複通知抑制によりmention_dm通知を作成しない
        expect(Notification.where(action: "mention_dm", visited_id: other_customer.id).count).to eq 0
      end

      it "添付ファイル付きの返信でも添付とreply_to_chat_message_idの両方が保存されること" do
        original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")

        post public_chat_messages_path, params: {
          chat_message: {
            content: "画像を送ります",
            chat_room_id: chat_room.id,
            customer_id: other_customer.id,
            reply_to_chat_message_id: original.id,
            attachments: [fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "image/png")]
          }
        }

        last_message = ChatMessage.last
        expect(last_message.reply_to_chat_message_id).to eq original.id
        expect(last_message.attachments).to be_attached
      end

      it "別のchat_room(別DM)のメッセージIDを指定してもreply_to_chat_message_idを保存しないこと" do
        other_chat_room = create(:chat_room)
        create(:chat_room_customer, chat_room: other_chat_room, customer: other_customer)
        foreign_message = create(:chat_message, customer: other_customer, chat_room: other_chat_room)

        post public_chat_messages_path, params: {
          chat_message: {
            content: "不正な返信",
            chat_room_id: chat_room.id,
            customer_id: other_customer.id,
            reply_to_chat_message_id: foreign_message.id
          }
        }
        expect(ChatMessage.last.reply_to_chat_message_id).to be_nil
      end

      it "存在しないreply_to_chat_message_idを指定してもエラーにならず通常投稿として保存されること" do
        expect do
          post public_chat_messages_path, params: {
            chat_message: {
              content: "存在しないIDへの返信",
              chat_room_id: chat_room.id,
              customer_id: other_customer.id,
              reply_to_chat_message_id: 999_999
            }
          }
        end.to change(ChatMessage, :count).by(1)
        expect(ChatMessage.last.reply_to_chat_message_id).to be_nil
      end

      it "自分自身の投稿への返信では通知を作成しないこと" do
        original = create(:chat_message, customer: customer, chat_room: chat_room, content: "自分の投稿")

        post public_chat_messages_path, params: {
          chat_message: {
            content: "自己レス",
            chat_room_id: chat_room.id,
            customer_id: other_customer.id,
            reply_to_chat_message_id: original.id
          }
        }
        expect(Notification.where(action: "reply_dm").count).to eq 0
      end

      it "通知作成中に例外が発生した場合、ChatMessageもChatMentionもロールバックされること" do
        original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
        allow(Chat::ReplyNotificationService).to receive(:call).and_raise(StandardError, "notification boom")

        expect do
          post public_chat_messages_path, params: {
            chat_message: {
              content: "[@相手](customer:#{other_customer.id}) 了解しました",
              chat_room_id: chat_room.id,
              customer_id: other_customer.id,
              reply_to_chat_message_id: original.id
            }
          }
        end.to raise_error(StandardError, "notification boom")

        expect(ChatMessage.count).to eq 1 # originalのみ(新規投稿はロールバックされている)
        expect(ChatMention.count).to eq 0
      end
    end

    context "返信機能のテスト(コミュニティ)" do
      let(:community) { create(:community) }
      let(:community_chat_room) { create(:chat_room) }
      let(:member) { create(:customer) }

      before do
        create(:chat_room_customer, chat_room: community_chat_room, customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: member, community: community)
        sign_in customer
      end

      it "同じコミュニティ内のメッセージへ返信するとreply_to_chat_message_idが保存されること" do
        original = create(:chat_message, customer: member, chat_room: community_chat_room, community: community,
                                           content: "元の投稿")

        post community_create_public_chat_messages_path, params: {
          chat_message: {
            content: "了解しました",
            chat_room_id: community_chat_room.id,
            reply_to_chat_message_id: original.id
          }
        }
        expect(ChatMessage.last.reply_to_chat_message_id).to eq original.id
      end

      it "メンション付きの返信でChatMentionと返信通知(reply_community)の両方が作成され、重複するmention_community通知は作成されないこと" do
        original = create(:chat_message, customer: member, chat_room: community_chat_room, community: community,
                                           content: "元の投稿")

        expect do
          post community_create_public_chat_messages_path, params: {
            chat_message: {
              content: "[@メンバー](customer:#{member.id}) 了解しました",
              chat_room_id: community_chat_room.id,
              reply_to_chat_message_id: original.id
            }
          }
        end.to change(ChatMention, :count).by(1)

        expect(Notification.where(action: "reply_community", visited_id: member.id).count).to eq 1
        expect(Notification.where(action: "mention_community", visited_id: member.id).count).to eq 0
      end

      it "添付ファイル付きの返信でも添付とreply_to_chat_message_idの両方が保存されること" do
        original = create(:chat_message, customer: member, chat_room: community_chat_room, community: community,
                                           content: "元の投稿")

        post community_create_public_chat_messages_path, params: {
          chat_message: {
            content: "画像を送ります",
            chat_room_id: community_chat_room.id,
            reply_to_chat_message_id: original.id,
            attachments: [fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "image/png")]
          }
        }

        last_message = ChatMessage.last
        expect(last_message.reply_to_chat_message_id).to eq original.id
        expect(last_message.attachments).to be_attached
      end

      it "別のコミュニティのメッセージIDを指定してもreply_to_chat_message_idを保存しないこと" do
        other_community = create(:community)
        other_chat_room = create(:chat_room)
        create(:chat_room_customer, chat_room: other_chat_room, customer: member, community: other_community)
        foreign_message = create(:chat_message, customer: member, chat_room: other_chat_room, community: other_community)

        post community_create_public_chat_messages_path, params: {
          chat_message: {
            content: "不正な返信",
            chat_room_id: community_chat_room.id,
            reply_to_chat_message_id: foreign_message.id
          }
        }
        expect(ChatMessage.last.reply_to_chat_message_id).to be_nil
      end

      it "通知作成中に例外が発生した場合、ChatMessageもChatMentionもロールバックされること" do
        original = create(:chat_message, customer: member, chat_room: community_chat_room, community: community,
                                           content: "元の投稿")
        allow(Chat::ReplyNotificationService).to receive(:call).and_raise(StandardError, "notification boom")

        expect do
          post community_create_public_chat_messages_path, params: {
            chat_message: {
              content: "[@メンバー](customer:#{member.id}) 了解しました",
              chat_room_id: community_chat_room.id,
              reply_to_chat_message_id: original.id
            }
          }
        end.to raise_error(StandardError, "notification boom")

        expect(ChatMessage.count).to eq 1
        expect(ChatMention.count).to eq 0
      end
    end

    context "引用返信機能のテスト(DM)" do
      before do
        create(:chat_room_customer, chat_room: chat_room, customer: customer)
        sign_in customer
      end

      it "quoted_chat_message_idを指定せずに通常投稿できること" do
        post public_chat_messages_path, params: {
          chat_message: { content: "お元気ですか？", chat_room_id: chat_room.id, customer_id: other_customer.id }
        }
        expect(ChatMessage.last.quoted_chat_message_id).to be_nil
      end

      it "同じchat_room内のメッセージを引用するとquoted_chat_message_idが保存されること" do
        original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "次回の曲を決めましょう")

        post public_chat_messages_path, params: {
          chat_message: {
            content: "この曲がいいと思います",
            chat_room_id: chat_room.id,
            customer_id: other_customer.id,
            quoted_chat_message_id: original.id
          }
        }
        expect(ChatMessage.last.quoted_chat_message_id).to eq original.id
      end

      it "自分自身のメッセージも引用できること" do
        original = create(:chat_message, customer: customer, chat_room: chat_room, content: "自分の投稿")

        post public_chat_messages_path, params: {
          chat_message: {
            content: "補足します",
            chat_room_id: chat_room.id,
            customer_id: other_customer.id,
            quoted_chat_message_id: original.id
          }
        }
        expect(ChatMessage.last.quoted_chat_message_id).to eq original.id
      end

      it "添付ファイル付きの引用返信でも添付とquoted_chat_message_idの両方が保存されること" do
        original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")

        post public_chat_messages_path, params: {
          chat_message: {
            content: "画像を送ります",
            chat_room_id: chat_room.id,
            customer_id: other_customer.id,
            quoted_chat_message_id: original.id,
            attachments: [fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "image/png")]
          }
        }

        last_message = ChatMessage.last
        expect(last_message.quoted_chat_message_id).to eq original.id
        expect(last_message.attachments).to be_attached
      end

      it "別のchat_room(別DM)のメッセージIDを指定してもquoted_chat_message_idを保存しないこと" do
        other_chat_room = create(:chat_room)
        create(:chat_room_customer, chat_room: other_chat_room, customer: other_customer)
        foreign_message = create(:chat_message, customer: other_customer, chat_room: other_chat_room)

        post public_chat_messages_path, params: {
          chat_message: {
            content: "不正な引用",
            chat_room_id: chat_room.id,
            customer_id: other_customer.id,
            quoted_chat_message_id: foreign_message.id
          }
        }
        expect(ChatMessage.last.quoted_chat_message_id).to be_nil
      end

      it "存在しないquoted_chat_message_idを指定してもエラーにならず通常投稿として保存されること" do
        expect do
          post public_chat_messages_path, params: {
            chat_message: {
              content: "存在しないIDへの引用",
              chat_room_id: chat_room.id,
              customer_id: other_customer.id,
              quoted_chat_message_id: 999_999
            }
          }
        end.to change(ChatMessage, :count).by(1)
        expect(ChatMessage.last.quoted_chat_message_id).to be_nil
      end

      it "引用しただけでは、引用元投稿者へ新規通知(reply_dm)を作成しないこと" do
        original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")

        post public_chat_messages_path, params: {
          chat_message: {
            content: "引用します",
            chat_room_id: chat_room.id,
            customer_id: other_customer.id,
            quoted_chat_message_id: original.id
          }
        }
        expect(Notification.where(action: "reply_dm", visited_id: other_customer.id).count).to eq 0
      end

      it "引用返信本文内で引用元投稿者を@メンションした場合、通常どおりメンション通知(mention_dm)が作成されること" do
        original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")

        expect do
          post public_chat_messages_path, params: {
            chat_message: {
              content: "[@相手](customer:#{other_customer.id}) 引用します",
              chat_room_id: chat_room.id,
              customer_id: other_customer.id,
              quoted_chat_message_id: original.id
            }
          }
        end.to change(ChatMention, :count).by(1)

        expect(Notification.where(action: "mention_dm", visited_id: other_customer.id).count).to eq 1
      end

      it "スレッド返信(reply_to_chat_message_id)と引用(quoted_chat_message_id)を同時に指定でき、両方が独立して保存されること" do
        thread_root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "スレッド元")
        quoted = create(:chat_message, customer: customer, chat_room: chat_room, content: "引用される投稿")

        post public_chat_messages_path, params: {
          chat_message: {
            content: "スレッド返信かつ引用",
            chat_room_id: chat_room.id,
            customer_id: other_customer.id,
            reply_to_chat_message_id: thread_root.id,
            quoted_chat_message_id: quoted.id
          }
        }

        last_message = ChatMessage.last
        expect(last_message.reply_to_chat_message_id).to eq thread_root.id
        expect(last_message.quoted_chat_message_id).to eq quoted.id
      end
    end

    context "引用返信機能のテスト(コミュニティ)" do
      let(:community) { create(:community) }
      let(:community_chat_room) { create(:chat_room) }
      let(:member) { create(:customer) }

      before do
        create(:chat_room_customer, chat_room: community_chat_room, customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: member, community: community)
        sign_in customer
      end

      it "同じコミュニティ内のメッセージを引用するとquoted_chat_message_idが保存されること" do
        original = create(:chat_message, customer: member, chat_room: community_chat_room, community: community,
                                           content: "元の投稿")

        post community_create_public_chat_messages_path, params: {
          chat_message: {
            content: "了解しました",
            chat_room_id: community_chat_room.id,
            quoted_chat_message_id: original.id
          }
        }
        expect(ChatMessage.last.quoted_chat_message_id).to eq original.id
      end

      it "別のコミュニティのメッセージIDを指定してもquoted_chat_message_idを保存しないこと" do
        other_community = create(:community)
        other_chat_room = create(:chat_room)
        create(:chat_room_customer, chat_room: other_chat_room, customer: member, community: other_community)
        foreign_message = create(:chat_message, customer: member, chat_room: other_chat_room, community: other_community)

        post community_create_public_chat_messages_path, params: {
          chat_message: {
            content: "不正な引用",
            chat_room_id: community_chat_room.id,
            quoted_chat_message_id: foreign_message.id
          }
        }
        expect(ChatMessage.last.quoted_chat_message_id).to be_nil
      end

      it "引用しただけでは、引用元投稿者へ新規通知(reply_community)を作成しないこと" do
        original = create(:chat_message, customer: member, chat_room: community_chat_room, community: community,
                                           content: "元の投稿")

        post community_create_public_chat_messages_path, params: {
          chat_message: {
            content: "引用します",
            chat_room_id: community_chat_room.id,
            quoted_chat_message_id: original.id
          }
        }
        expect(Notification.where(action: "reply_community", visited_id: member.id).count).to eq 0
      end
    end

    context "content_formatのテスト(要件11の後方互換性)" do
      before do
        create(:chat_room_customer, chat_room: chat_room, customer: customer)
        sign_in customer
      end

      it "createアクションで新規投稿すると content_format が markdown で保存されること" do
        post public_chat_messages_path, params: {
          chat_message: { content: "お元気ですか？", chat_room_id: chat_room.id, customer_id: other_customer.id }
        }
        expect(ChatMessage.last.content_format).to eq "markdown"
      end
    end
    context "previewアクションのテスト" do
      before { sign_in customer }

      it "200 OKで、レンダリング済みHTMLをJSONで返すこと" do
        post preview_public_chat_messages_path, params: { content: "**bold**" }, as: :json
        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)["html"]).to include("<strong>bold</strong>")
      end

      it "DBには何も保存しないこと" do
        expect do
          post preview_public_chat_messages_path, params: { content: "**bold**" }, as: :json
        end.not_to change(ChatMessage, :count)
      end

      it "XSSを含む入力はサニタイズされたHTMLを返すこと" do
        post preview_public_chat_messages_path, params: { content: "<script>alert(1)</script>" }, as: :json
        expect(JSON.parse(response.body)["html"]).not_to include("<script")
      end

      it "空文字を渡しても500にならず、空のHTMLを返すこと" do
        post preview_public_chat_messages_path, params: { content: "" }, as: :json
        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)["html"]).to eq ""
      end

      it "contentパラメータ自体が無くても500にならないこと" do
        post preview_public_chat_messages_path, params: {}, as: :json
        expect(response).to have_http_status(200)
      end

      it "極端に長い入力でも例外にならず、上限文字数までで処理されること" do
        huge_input = "a" * 100_000
        post preview_public_chat_messages_path, params: { content: huge_input }, as: :json
        expect(response).to have_http_status(200)
        html = JSON.parse(response.body)["html"]
        expect(html.length).to be <= Chat::MarkdownRenderer::MAX_LENGTH + 50 # HTMLタグ分の余裕
      end

      it "レスポンスのContent-TypeがJSONであること" do
        post preview_public_chat_messages_path, params: { content: "**bold**" }, as: :json
        expect(response.content_type).to include("application/json")
      end

      it "GETではアクセスできないこと(ルーティングエラー)" do
        expect do
          get preview_public_chat_messages_path
        end.to raise_error(ActionController::RoutingError)
      end

      it "レンダリング中に予期しない例外が発生してもスタックトレース等を漏らさず、汎用エラーメッセージを返すこと" do
        allow(Chat::MarkdownRenderer).to receive(:call).and_raise(StandardError, "internal boom")

        post preview_public_chat_messages_path, params: { content: "**bold**" }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq "プレビューを生成できませんでした"
        expect(response.body).not_to include("internal boom")
        expect(response.body).not_to include("markdown_renderer.rb")
      end
    end
    context "非ログイン" do
      it "リクエストは302 Foundとなること" do
        post "/public/chat_messages", params: {
          chat_message: {
            context: "お元気ですか？",
            chat_room_id: 1,
            customer_id: 1,
          }
        }
        expect(response).to have_http_status "302"
      end
      it "ログイン画面にリダイレクトされているか？" do
        post "/public/chat_messages", params: {
          chat_message: {
            context: "お元気ですか？",
            chat_room_id: 1,
            customer_id: 1,
          }
        }
        expect(response).to redirect_to "/customers/sign_in"
      end

      it "previewアクションも302 Foundとなること" do
        post preview_public_chat_messages_path, params: { content: "**bold**" }, as: :json
        expect(response).to have_http_status "302"
      end
    end
  end
end