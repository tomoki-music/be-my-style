require "rails_helper"

RSpec.describe Chat::LinkPreviews::EventFetcher, type: :service do
  let(:community) { create(:community, name: "テストコミュニティ") }
  let(:customer) { create(:customer) }
  let(:event) { create(:event, :event_with_songs, customer: customer, community: community, event_name: "テストイベント") }

  it "同期的に解決すること(synchronous?がtrueであること)" do
    expect(described_class.synchronous?).to eq true
  end

  it "Eventのタイトル・コミュニティ名を取得すること" do
    result = described_class.call("https://www.example.com/public/events/#{event.id}")

    expect(result[:title]).to eq "テストイベント"
    expect(result[:author_name]).to eq "テストコミュニティ"
  end

  it "画像未添付の場合はthumbnail_urlがnilになること" do
    result = described_class.call("https://www.example.com/public/events/#{event.id}")

    expect(result[:thumbnail_url]).to be_nil
  end

  it "存在しないEventの場合はNotFoundErrorにすること" do
    expect {
      described_class.call("https://www.example.com/public/events/#{event.id + 1_000_000}")
    }.to raise_error(Chat::LinkPreviews::EventFetcher::NotFoundError)
  end
end
