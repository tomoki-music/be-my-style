require 'rails_helper'

RSpec.describe SingingDiagnoses::AnalyzerClient do
  class SingingAnalyzerFakeHttp
    attr_accessor :use_ssl, :open_timeout, :read_timeout
    attr_reader :request_object

    def initialize(_host, _port)
    end

    def request(request)
      @request_object = request
      Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
        body = {
          overall_score: 86,
          pitch_score: 82,
          rhythm_score: 90,
          expression_score: 84
        }.to_json
        response.define_singleton_method(:body) { body }
      end
    end
  end

  class SingingAnalyzerFailedHttp
    attr_accessor :use_ssl, :open_timeout, :read_timeout

    def initialize(_host, _port)
    end

    def request(_request)
      Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error").tap do |response|
        response.define_singleton_method(:body) { "error" }
      end
    end
  end

  describe "#submit" do
    it "multipartで音声ファイルと診断情報を送信しHashを返すこと" do
      diagnosis = FactoryBot.create(:singing_diagnosis, song_title: "Sample Song", memo: "memo")
      http_class = class_spy("Net::HTTP")
      fake_http = SingingAnalyzerFakeHttp.new("example.com", 443)

      allow(http_class).to receive(:new).and_return(fake_http)

      result = described_class.new(
        endpoint_url: "https://example.com/diagnoses",
        http_class: http_class
      ).submit(diagnosis)

      expect(result).to eq(
        "overall_score" => 86,
        "pitch_score" => 82,
        "rhythm_score" => 90,
        "expression_score" => 84
      )
      expect(fake_http.use_ssl).to eq true
      expect(fake_http.request_object.path).to eq "/diagnoses"
      expect(fake_http.request_object.content_type).to include("multipart/form-data")
      expect(fake_http.request_object.instance_variable_get(:@body_data)).to include(["performance_type", "vocal"])
    end

    it "参照キーとBPMが保存されている場合はmultipartに含めること" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        result_payload: {
          "reference_input" => {
            "reference_key" => "C",
            "reference_bpm" => "120"
          }
        }
      )
      http_class = class_spy("Net::HTTP")
      fake_http = SingingAnalyzerFakeHttp.new("example.com", 443)

      allow(http_class).to receive(:new).and_return(fake_http)

      described_class.new(
        endpoint_url: "https://example.com/diagnoses",
        http_class: http_class
      ).submit(diagnosis)

      body_data = fake_http.request_object.instance_variable_get(:@body_data)
      expect(body_data).to include(["reference_key", "C"])
      expect(body_data).to include(["reference_bpm", "120"])
    end

    it "endpoint未設定の場合は設定エラーにすること" do
      diagnosis = FactoryBot.build(:singing_diagnosis)

      expect do
        described_class.new(endpoint_url: nil).submit(diagnosis)
      end.to raise_error(SingingDiagnoses::AnalyzerClient::ConfigurationError)
    end

    it "HTTP失敗時はRequestErrorにすること" do
      diagnosis = FactoryBot.create(:singing_diagnosis)
      http_class = class_spy("Net::HTTP")

      allow(http_class).to receive(:new).and_return(SingingAnalyzerFailedHttp.new("example.com", 443))

      expect do
        described_class.new(
          endpoint_url: "https://example.com/diagnoses",
          http_class: http_class
        ).submit(diagnosis)
      end.to raise_error(SingingDiagnoses::AnalyzerClient::RequestError)
    end

    it "接続拒否（ECONNREFUSED）のときはConnectionErrorを発生させること" do
      diagnosis = FactoryBot.create(:singing_diagnosis)
      raising_http = SingingAnalyzerFakeHttp.new("example.com", 443)
      allow(raising_http).to receive(:request).and_raise(Errno::ECONNREFUSED)
      http_class = class_spy("Net::HTTP")
      allow(http_class).to receive(:new).and_return(raising_http)

      expect do
        described_class.new(
          endpoint_url: "https://example.com/diagnoses",
          http_class: http_class
        ).submit(diagnosis)
      end.to raise_error(SingingDiagnoses::AnalyzerClient::ConnectionError)
    end

    it "タイムアウト時はTimeoutErrorを発生させること" do
      diagnosis = FactoryBot.create(:singing_diagnosis)
      raising_http = SingingAnalyzerFakeHttp.new("example.com", 443)
      allow(raising_http).to receive(:request).and_raise(Net::OpenTimeout)
      http_class = class_spy("Net::HTTP")
      allow(http_class).to receive(:new).and_return(raising_http)

      expect do
        described_class.new(
          endpoint_url: "https://example.com/diagnoses",
          http_class: http_class
        ).submit(diagnosis)
      end.to raise_error(SingingDiagnoses::AnalyzerClient::TimeoutError)
    end
  end
end
