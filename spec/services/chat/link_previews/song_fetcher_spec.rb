require "rails_helper"

RSpec.describe Chat::LinkPreviews::SongFetcher, type: :service do
  let(:community) { create(:community) }
  let(:customer) { create(:customer) }
  let(:event) { create(:event, :event_with_songs, customer: customer, community: community) }
  let(:other_event) { create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { create(:song, event: event, song_name: "テスト楽曲", artist_name: "テストアーティスト") }

  it "同期的に解決すること(synchronous?がtrueであること)" do
    expect(described_class.synchronous?).to eq true
  end

  it "曲名・アーティスト名を取得すること" do
    result = described_class.call("https://www.example.com/public/events/#{event.id}/songs/#{song.id}")

    expect(result[:title]).to eq "テスト楽曲"
    expect(result[:author_name]).to eq "テストアーティスト"
  end

  it "thumbnail_urlは常にnilであること(MVPでは画像を扱わない)" do
    result = described_class.call("https://www.example.com/public/events/#{event.id}/songs/#{song.id}")

    expect(result[:thumbnail_url]).to be_nil
  end

  it "アーティスト名が未入力の場合はauthor_nameがnilであること" do
    no_artist_song = create(:song, event: event, song_name: "アーティスト未設定曲", artist_name: nil)

    result = described_class.call("https://www.example.com/public/events/#{event.id}/songs/#{no_artist_song.id}")

    expect(result[:author_name]).to be_nil
  end

  it "存在しないSongの場合はNotFoundErrorにすること" do
    expect {
      described_class.call("https://www.example.com/public/events/#{event.id}/songs/#{song.id + 1_000_000}")
    }.to raise_error(Chat::LinkPreviews::SongFetcher::NotFoundError)
  end

  it "URL上のevent_idと実際のSongのevent_idが一致しない場合はNotFoundErrorにすること(別イベントのSong ID流用対策)" do
    expect {
      described_class.call("https://www.example.com/public/events/#{other_event.id}/songs/#{song.id}")
    }.to raise_error(Chat::LinkPreviews::SongFetcher::NotFoundError)
  end
end
