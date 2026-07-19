require 'rails_helper'

RSpec.describe 'ChatMessageモデルのテスト', type: :model do
  let(:customer) { FactoryBot.create(:customer) }
  let(:other_customer) { FactoryBot.create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:chat_message) { FactoryBot.create(:chat_message, customer: other_customer, chat_room: chat_room) }

  describe 'アソシエーションのテスト' do
    context 'チャットメッセージ機能において' do
      it 'CustomersとN:1となっている' do
        expect(ChatMessage.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'chat_roomsとN:1となっている' do
        expect(ChatMessage.reflect_on_association(:chat_room).macro).to eq :belongs_to
      end
      it 'communitiesとN:1となっている' do
        expect(ChatMessage.reflect_on_association(:community).macro).to eq :belongs_to
      end
    end

    context '返信機能(reply_to_chat_message)において' do
      it 'reply_to_chat_messageはChatMessageへのbelongs_toかつoptionalである' do
        reflection = ChatMessage.reflect_on_association(:reply_to_chat_message)
        expect(reflection.macro).to eq :belongs_to
        expect(reflection.klass).to eq ChatMessage
        expect(reflection.options[:optional]).to eq true
      end

      it 'repliesはChatMessageへのhas_manyかつdependent: :nullifyである' do
        reflection = ChatMessage.reflect_on_association(:replies)
        expect(reflection.macro).to eq :has_many
        expect(reflection.klass).to eq ChatMessage
        expect(reflection.options[:dependent]).to eq :nullify
      end

      it '返信元を指定せずに保存できる(通常投稿として)' do
        message = create(:chat_message, customer: customer, chat_room: chat_room)
        expect(message.reply_to_chat_message).to be_nil
      end

      it '自分自身の投稿を含め、同じchat_room内の別メッセージへ自己参照で返信できる' do
        original = create(:chat_message, customer: customer, chat_room: chat_room, content: "元の投稿")
        reply = create(:chat_message, customer: other_customer, chat_room: chat_room,
                                       content: "返信です", reply_to_chat_message: original)

        expect(reply.reply_to_chat_message).to eq original
        expect(original.reload.replies).to include(reply)
      end

      it '返信元メッセージが削除されても、返信メッセージ自体は削除されずreply_to_chat_message_idがnilになる' do
        original = create(:chat_message, customer: customer, chat_room: chat_room, content: "元の投稿")
        reply = create(:chat_message, customer: other_customer, chat_room: chat_room,
                                       content: "返信です", reply_to_chat_message: original)

        expect { original.destroy }.to change(ChatMessage, :count).by(-1)
        expect(ChatMessage.exists?(reply.id)).to eq true
        expect(reply.reload.reply_to_chat_message_id).to be_nil
      end
    end

    context "スレッドの親(thread_root)において" do
      it "返信元を持たないメッセージ自身のthread_rootは自分自身である" do
        original = create(:chat_message, customer: customer, chat_room: chat_room, content: "元の投稿")
        expect(original.thread_root).to eq original
      end

      it "返信元を持つメッセージのthread_rootは、その返信元(親)である" do
        original = create(:chat_message, customer: customer, chat_room: chat_room, content: "元の投稿")
        reply = create(:chat_message, customer: other_customer, chat_room: chat_room,
                                       content: "返信です", reply_to_chat_message: original)

        expect(reply.thread_root).to eq original
      end

      it "循環参照のような壊れたデータがあっても、深さの上限で終了し無限ループしない" do
        a = create(:chat_message, customer: customer, chat_room: chat_room, content: "A")
        b = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "B")
        # 通常のアプリケーションコードでは発生しない循環参照を、update_columnで強制的に作る
        a.update_column(:reply_to_chat_message_id, b.id)
        b.update_column(:reply_to_chat_message_id, a.id)

        result = nil
        expect { result = a.reload.thread_root }.not_to raise_error
        expect([a.id, b.id]).to include(result.id)
      end
    end

    context "返信件数(replies_count、counter cache)において" do
      it "返信を作成すると、返信元(親)のreplies_countが1増える" do
        original = create(:chat_message, customer: customer, chat_room: chat_room, content: "元の投稿")

        expect do
          create(:chat_message, customer: other_customer, chat_room: chat_room,
                                 content: "返信です", reply_to_chat_message: original)
        end.to change { original.reload.replies_count }.by(1)
      end

      it "返信元を持たないメッセージのreplies_countは0のままである" do
        message = create(:chat_message, customer: customer, chat_room: chat_room)
        expect(message.replies_count).to eq 0
      end

      it "返信を削除すると、返信元(親)のreplies_countが1減る" do
        original = create(:chat_message, customer: customer, chat_room: chat_room, content: "元の投稿")
        reply = create(:chat_message, customer: other_customer, chat_room: chat_room,
                                       content: "返信です", reply_to_chat_message: original)
        expect(original.reload.replies_count).to eq 1

        expect { reply.destroy }.to change { original.reload.replies_count }.by(-1)
      end

      it "返信先を付け替えると、旧親のreplies_countが減り、新しい親のreplies_countが増える" do
        old_root = create(:chat_message, customer: customer, chat_room: chat_room, content: "旧親")
        new_root = create(:chat_message, customer: customer, chat_room: chat_room, content: "新しい親")
        reply = create(:chat_message, customer: other_customer, chat_room: chat_room,
                                       content: "返信です", reply_to_chat_message: old_root)
        expect(old_root.reload.replies_count).to eq 1
        expect(new_root.reload.replies_count).to eq 0

        reply.update!(reply_to_chat_message: new_root)

        expect(old_root.reload.replies_count).to eq 0
        expect(new_root.reload.replies_count).to eq 1
      end

      it "返信先が既に返信メッセージだった場合にthread_rootへ正規化して保存すると、最上位の親だけreplies_countが増える" do
        root = create(:chat_message, customer: customer, chat_room: chat_room, content: "元の投稿")
        reply1 = create(:chat_message, customer: other_customer, chat_room: chat_room,
                                        content: "1件目の返信", reply_to_chat_message: root)

        # Chat::ReplyTargetResolverが行う正規化(candidate.thread_root)を模して保存する。
        reply2 = create(:chat_message, customer: customer, chat_room: chat_room,
                                        content: "2件目の返信", reply_to_chat_message: reply1.thread_root)

        expect(reply2.reply_to_chat_message_id).to eq root.id
        expect(root.reload.replies_count).to eq 2
        expect(reply1.reload.replies_count).to eq 0
      end

      it "親メッセージがdependent: :nullifyで削除されても、残った返信同士のreplies_countは不整合にならない(削除された親は自身ごと消えるため対象外)" do
        root = create(:chat_message, customer: customer, chat_room: chat_room, content: "元の投稿")
        reply1 = create(:chat_message, customer: other_customer, chat_room: chat_room,
                                        content: "返信1", reply_to_chat_message: root)
        reply2 = create(:chat_message, customer: customer, chat_room: chat_room,
                                        content: "返信2", reply_to_chat_message: root)

        root.destroy

        expect(reply1.reload.reply_to_chat_message_id).to be_nil
        expect(reply2.reload.reply_to_chat_message_id).to be_nil
        expect(reply1.replies_count).to eq 0
        expect(reply2.replies_count).to eq 0
      end
    end
  end
  describe 'バリデーションのテスト' do
    context 'チャットメッセージ機能について' do
      it 'メッセージが入力されていると正しく送信できる' do
        chat_message.content = '良いお天気ですね！'
        expect(chat_message.valid?).to eq true
      end
      it 'メッセージが空欄だとエラーになる' do
        chat_message.content = ''
        expect(chat_message.valid?).to eq false
      end
    end
  end
end