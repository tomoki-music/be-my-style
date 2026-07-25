require "rails_helper"

RSpec.describe Chat::SongLinkPreviewLoader, type: :service do
  let(:community) { create(:community) }
  let(:customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:event) { create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { create(:song, event: event) }

  it "provider: songのプレビューが参照するSongをまとめて解決すること" do
    chat_message = create(:chat_message, customer: customer, chat_room: chat_room)
    create(:chat_message_link_preview, :song, chat_message: chat_message, external_id: song.id.to_s)

    result = described_class.call([chat_message])

    expect(result[song.id.to_s]).to eq song
  end

  it "eventのプレビューは対象外にすること" do
    chat_message = create(:chat_message, customer: customer, chat_room: chat_room)
    create(:chat_message_link_preview, :event, chat_message: chat_message, external_id: "1")

    result = described_class.call([chat_message])

    expect(result).to eq({})
  end

  it "存在しないSongは結果に含まれないこと" do
    chat_message = create(:chat_message, customer: customer, chat_room: chat_room)
    create(:chat_message_link_preview, :song, chat_message: chat_message, external_id: "999999")

    result = described_class.call([chat_message])

    expect(result).to eq({})
  end

  it "複数メッセージ分のSongを1回のクエリでまとめて解決すること(N+1対策)" do
    other_song = create(:song, event: event)
    chat_message1 = create(:chat_message, customer: customer, chat_room: chat_room)
    chat_message2 = create(:chat_message, customer: customer, chat_room: chat_room)
    create(:chat_message_link_preview, :song, chat_message: chat_message1, external_id: song.id.to_s)
    create(:chat_message_link_preview, :song, chat_message: chat_message2, external_id: other_song.id.to_s, position: 0)

    result = described_class.call([chat_message1, chat_message2])

    expect(result.keys).to contain_exactly(song.id.to_s, other_song.id.to_s)
  end
end
