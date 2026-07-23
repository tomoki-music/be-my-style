require "rails_helper"

RSpec.describe Chat::LinkPreviews::YoutubeFetcher do
  def stub_http(response)
    http = instance_double(Net::HTTP, request: response)
    http_class = class_spy("Net::HTTP")

    allow(http_class).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)

    http_class
  end

  it "oEmbedからtitle/author_name/thumbnail_urlを取得すること" do
    body = { title: "テスト動画", author_name: "テストチャンネル", thumbnail_url: "https://i.ytimg.com/vi/xxx/hqdefault.jpg" }.to_json
    response = double("Net::HTTPOK", body: body)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    http_class = stub_http(response)

    result = described_class.new(http_class: http_class).call("https://www.youtube.com/watch?v=dQw4w9WgXcQ")

    expect(result).to eq(
      title: "テスト動画",
      author_name: "テストチャンネル",
      thumbnail_url: "https://i.ytimg.com/vi/xxx/hqdefault.jpg"
    )
    expect(http_class).to have_received(:new).with("www.youtube.com", 443)
  end

  it "動画が削除・非公開等で404の場合はRequestErrorにすること" do
    response = double("Net::HTTPNotFound", body: "Not Found", code: "404")
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    http_class = stub_http(response)

    expect {
      described_class.new(http_class: http_class).call("https://www.youtube.com/watch?v=deleted0000")
    }.to raise_error(Chat::LinkPreviews::YoutubeFetcher::RequestError)
  end

  it "タイムアウトした場合はTimeoutErrorにすること" do
    http = instance_double(Net::HTTP)
    http_class = class_spy("Net::HTTP")
    allow(http_class).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_raise(Net::ReadTimeout)

    expect {
      described_class.new(http_class: http_class).call("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }.to raise_error(Chat::LinkPreviews::YoutubeFetcher::TimeoutError)
  end

  it "不正なJSONを返した場合はResponseFormatErrorにすること" do
    response = double("Net::HTTPOK", body: "{")
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    http_class = stub_http(response)

    expect {
      described_class.new(http_class: http_class).call("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }.to raise_error(Chat::LinkPreviews::YoutubeFetcher::ResponseFormatError)
  end

  it "レスポンスサイズが上限を超える場合はResponseFormatErrorにすること" do
    oversized_title = "a" * (Chat::LinkPreviews::YoutubeFetcher::MAX_RESPONSE_BYTES + 1)
    response = double("Net::HTTPOK", body: { title: oversized_title }.to_json)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    http_class = stub_http(response)

    expect {
      described_class.new(http_class: http_class).call("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }.to raise_error(Chat::LinkPreviews::YoutubeFetcher::ResponseFormatError)
  end

  it "デフォルトタイムアウトは3秒であること" do
    expect(described_class.new.send(:timeout)).to eq 3
  end
end
