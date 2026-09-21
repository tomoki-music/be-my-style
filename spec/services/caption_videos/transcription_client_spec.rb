require "rails_helper"

RSpec.describe CaptionVideos::TranscriptionClient do
  let(:tmp_dir) { Dir.mktmpdir("transcription_client_spec") }
  let(:audio_path) { File.join(tmp_dir, "audio.mp3") }

  before { File.write(audio_path, "dummy audio bytes") }
  after { FileUtils.remove_entry(tmp_dir) }

  describe "#transcribe" do
    it "segments配列を返すこと" do
      body = { segments: [{ start: 0.0, end: 1.5, text: "こんにちは" }] }.to_json
      response = double("Net::HTTPOK", body: body)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      http = instance_double(Net::HTTP, request: response)
      http_class = class_spy("Net::HTTP")
      allow(http_class).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      client = described_class.new(api_key: "test-key", http_class: http_class)
      segments = client.transcribe(audio_path: audio_path, language: "ja")

      expect(segments).to eq([{ start: 0.0, end: 1.5, text: "こんにちは" }])
    end

    it "空文字のsegmentは除外されること" do
      body = { segments: [{ start: 0.0, end: 1.0, text: "  " }, { start: 1.0, end: 2.0, text: "有効" }] }.to_json
      response = double("Net::HTTPOK", body: body)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      http = instance_double(Net::HTTP, request: response)
      http_class = class_spy("Net::HTTP")
      allow(http_class).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      client = described_class.new(api_key: "test-key", http_class: http_class)
      segments = client.transcribe(audio_path: audio_path)

      expect(segments.size).to eq(1)
      expect(segments.first[:text]).to eq("有効")
    end

    it "APIキー未設定の場合はConfigurationErrorになること" do
      client = described_class.new(api_key: "")

      expect do
        client.transcribe(audio_path: audio_path)
      end.to raise_error(described_class::ConfigurationError)
    end

    it "音声ファイルが存在しない場合はRequestErrorになること" do
      client = described_class.new(api_key: "test-key")

      expect do
        client.transcribe(audio_path: "/nonexistent/audio.mp3")
      end.to raise_error(described_class::RequestError)
    end

    it "OpenAI APIが失敗した場合はRequestErrorになること(レスポンス本文を含まないこと)" do
      response = double("Net::HTTPInternalServerError", body: "secret internal error detail")
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(response).to receive(:code).and_return("500")
      http = instance_double(Net::HTTP, request: response)
      http_class = class_spy("Net::HTTP")
      allow(http_class).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      client = described_class.new(api_key: "test-key", http_class: http_class)

      expect do
        client.transcribe(audio_path: audio_path)
      end.to raise_error(described_class::RequestError) { |e| expect(e.message).not_to include("secret internal error detail") }
    end

    it "タイムアウトした場合はTimeoutErrorになること" do
      http = instance_double(Net::HTTP)
      http_class = class_spy("Net::HTTP")
      allow(http_class).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_raise(Net::ReadTimeout)

      client = described_class.new(api_key: "test-key", http_class: http_class)

      expect do
        client.transcribe(audio_path: audio_path)
      end.to raise_error(described_class::TimeoutError)
    end

    it "segmentsが無いレスポンスはResponseFormatErrorになること" do
      response = double("Net::HTTPOK", body: { foo: "bar" }.to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      http = instance_double(Net::HTTP, request: response)
      http_class = class_spy("Net::HTTP")
      allow(http_class).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      client = described_class.new(api_key: "test-key", http_class: http_class)

      expect do
        client.transcribe(audio_path: audio_path)
      end.to raise_error(described_class::ResponseFormatError)
    end
  end
end
