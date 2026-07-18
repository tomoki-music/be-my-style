require "rails_helper"

RSpec.describe ChatMention, type: :model do
  let(:customer) { create(:customer) }
  let(:mentioned_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:chat_message) { create(:chat_message, :markdown, customer: customer, chat_room: chat_room) }

  describe "アソシエーション" do
    it "chat_messageとN:1となっていること" do
      expect(described_class.reflect_on_association(:chat_message).macro).to eq :belongs_to
    end

    it "mentioned_customerがCustomerへのN:1となっていること" do
      reflection = described_class.reflect_on_association(:mentioned_customer)
      expect(reflection.macro).to eq :belongs_to
      expect(reflection.klass).to eq Customer
    end
  end

  describe "unique制約" do
    it "同一メッセージ×同一ユーザーの組み合わせは2件目を作成できないこと" do
      create(:chat_mention, chat_message: chat_message, mentioned_customer: mentioned_customer)
      duplicate = build(:chat_mention, chat_message: chat_message, mentioned_customer: mentioned_customer)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "ChatMessage/Customer側の関連" do
    it "ChatMessage#mentioned_customersでメンション先が取得できること" do
      create(:chat_mention, chat_message: chat_message, mentioned_customer: mentioned_customer)
      expect(chat_message.mentioned_customers).to include(mentioned_customer)
    end

    it "Customer#received_chat_mentions/mentioning_chat_messagesでメンションされた記録が取得できること" do
      create(:chat_mention, chat_message: chat_message, mentioned_customer: mentioned_customer)
      expect(mentioned_customer.received_chat_mentions.map(&:chat_message)).to include(chat_message)
      expect(mentioned_customer.mentioning_chat_messages).to include(chat_message)
    end
  end
end
