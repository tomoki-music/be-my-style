require "rails_helper"

RSpec.describe Chat::LinkPreviews::ProviderResolver do
  it "youtubeに対応するFetcherを返すこと" do
    expect(described_class.fetcher_for(:youtube)).to eq Chat::LinkPreviews::YoutubeFetcher
    expect(described_class.fetcher_for("youtube")).to eq Chat::LinkPreviews::YoutubeFetcher
  end

  it "未対応のproviderはArgumentErrorにすること" do
    expect { described_class.fetcher_for(:spotify) }.to raise_error(ArgumentError)
  end
end
