require "rails_helper"

RSpec.describe ChatMessagePin, type: :model do
  let(:customer) { create(:customer) }
  let(:pinned_by_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:chat_message) { create(:chat_message, customer: customer, chat_room: chat_room) }

  describe "アソシエーション" do
    it "chat_messageとN:1となっていること" do
      expect(described_class.reflect_on_association(:chat_message).macro).to eq :belongs_to
    end

    it "pinned_by_customerがCustomerへのN:1となっていること" do
      reflection = described_class.reflect_on_association(:pinned_by_customer)
      expect(reflection.macro).to eq :belongs_to
      expect(reflection.klass).to eq Customer
    end
  end

  describe "unique制約" do
    it "同一メッセージへの2件目のピンは作成できないこと" do
      create(:chat_message_pin, chat_message: chat_message, pinned_by_customer: pinned_by_customer)
      duplicate = build(:chat_message_pin, chat_message: chat_message, pinned_by_customer: pinned_by_customer)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "ChatMessage側の関連" do
    it "ChatMessage#chat_message_pinでピン留め情報が取得できること" do
      pin = create(:chat_message_pin, chat_message: chat_message, pinned_by_customer: pinned_by_customer)
      expect(chat_message.reload.chat_message_pin).to eq pin
    end

    it "ChatMessage#pinned?がピン留め状態を返すこと" do
      expect(chat_message.pinned?).to be false

      create(:chat_message_pin, chat_message: chat_message, pinned_by_customer: pinned_by_customer)
      expect(chat_message.reload.pinned?).to be true
    end

    it "ChatMessageを破棄するとChatMessagePinも破棄されること(dependent: :destroy)" do
      create(:chat_message_pin, chat_message: chat_message, pinned_by_customer: pinned_by_customer)

      expect { chat_message.destroy }.to change(ChatMessagePin, :count).by(-1)
    end
  end
end
