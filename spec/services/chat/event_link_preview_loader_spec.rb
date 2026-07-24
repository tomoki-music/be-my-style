require "rails_helper"

RSpec.describe Chat::EventLinkPreviewLoader, type: :service do
  let(:community) { create(:community) }
  let(:customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:event) { create(:event, :event_with_songs, customer: customer, community: community) }

  it "provider: eventのプレビューが参照するEventをまとめて解決すること" do
    chat_message = create(:chat_message, customer: customer, chat_room: chat_room)
    create(:chat_message_link_preview, :event, chat_message: chat_message, external_id: event.id.to_s)

    result = described_class.call([chat_message])

    expect(result[event.id.to_s]).to eq event
  end

  it "youtubeのプレビューは対象外にすること" do
    chat_message = create(:chat_message, customer: customer, chat_room: chat_room)
    create(:chat_message_link_preview, chat_message: chat_message)

    result = described_class.call([chat_message])

    expect(result).to eq({})
  end

  it "存在しないEventは結果に含まれないこと" do
    chat_message = create(:chat_message, customer: customer, chat_room: chat_room)
    create(:chat_message_link_preview, :event, chat_message: chat_message, external_id: "999999")

    result = described_class.call([chat_message])

    expect(result).to eq({})
  end
end
