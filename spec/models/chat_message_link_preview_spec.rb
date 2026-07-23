require "rails_helper"

RSpec.describe ChatMessageLinkPreview, type: :model do
  let(:customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:chat_message) { create(:chat_message, customer: customer, chat_room: chat_room) }

  describe "アソシエーション" do
    it "chat_messageとN:1となっていること" do
      expect(described_class.reflect_on_association(:chat_message).macro).to eq :belongs_to
    end
  end

  describe "unique制約" do
    it "同一メッセージ・同一positionの2件目は作成できないこと" do
      create(:chat_message_link_preview, chat_message: chat_message, position: 0)
      duplicate = build(:chat_message_link_preview, chat_message: chat_message, position: 0, external_id: "bbbbbbbbbbb")

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "ChatMessage側の関連" do
    it "ChatMessageを破棄するとChatMessageLinkPreviewも破棄されること(dependent: :destroy)" do
      create(:chat_message_link_preview, chat_message: chat_message)

      expect { chat_message.destroy }.to change(ChatMessageLinkPreview, :count).by(-1)
    end

    it "ChatMessage#chat_message_link_previewsがposition順に並ぶこと" do
      third = create(:chat_message_link_preview, chat_message: chat_message, position: 2, external_id: "ccccccccccc")
      first = create(:chat_message_link_preview, chat_message: chat_message, position: 0, external_id: "aaaaaaaaaaa")
      second = create(:chat_message_link_preview, chat_message: chat_message, position: 1, external_id: "bbbbbbbbbbb")

      expect(chat_message.reload.chat_message_link_previews.to_a).to eq [first, second, third]
    end
  end

  describe "#cache_fresh?" do
    it "fetched かつ 30日以内の場合はtrueであること" do
      preview = create(:chat_message_link_preview, chat_message: chat_message, status: :fetched, fetched_at: 1.day.ago)
      expect(preview.cache_fresh?).to be true
    end

    it "fetched でも30日より古い場合はfalseであること" do
      preview = create(:chat_message_link_preview, chat_message: chat_message, status: :fetched, fetched_at: 31.days.ago)
      expect(preview.cache_fresh?).to be false
    end

    it "pendingの場合はfalseであること" do
      preview = create(:chat_message_link_preview, chat_message: chat_message, status: :pending)
      expect(preview.cache_fresh?).to be false
    end

    it "failedの場合はfalseであること" do
      preview = create(:chat_message_link_preview, chat_message: chat_message, status: :failed)
      expect(preview.cache_fresh?).to be false
    end
  end
end
