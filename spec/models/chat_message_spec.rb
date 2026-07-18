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