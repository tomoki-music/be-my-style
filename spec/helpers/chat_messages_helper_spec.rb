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
end
