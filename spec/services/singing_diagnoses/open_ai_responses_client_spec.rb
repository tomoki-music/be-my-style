require 'rails_helper'

RSpec.describe SingingDiagnoses::OpenAiResponsesClient do
  describe "#generate_text" do
    it "Responses APIへリクエストしてoutput_textを返すこと" do
      response = double("Net::HTTPOK", body: { output_text: "練習コメントです。" }.to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      http = instance_double(Net::HTTP, request: response)
      http_class = class_spy("Net::HTTP")

      allow(http_class).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      client = described_class.new(api_key: "test-key", model: "test-model", http_class: http_class)

      text = client.generate_text(input: "input", instructions: "instructions")

      expect(text).to eq "練習コメントです。"
      expect(http_class).to have_received(:new).with("api.openai.com", 443)
    end

    it "APIキー未設定の場合はConfigurationErrorにすること" do
      client = described_class.new(api_key: "", model: "test-model")

      expect do
        client.generate_text(input: "input", instructions: "instructions")
      end.to raise_error(SingingDiagnoses::OpenAiResponsesClient::ConfigurationError)
    end

    it "OpenAI APIが失敗した場合はRequestErrorにすること" do
      response = double("Net::HTTPInternalServerError", body: "error")
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(response).to receive(:code).and_return("500")
      http = instance_double(Net::HTTP, request: response)
      http_class = class_spy("Net::HTTP")

      allow(http_class).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)

      client = described_class.new(api_key: "test-key", model: "test-model", http_class: http_class)

      expect do
        client.generate_text(input: "input", instructions: "instructions")
      end.to raise_error(SingingDiagnoses::OpenAiResponsesClient::RequestError)
    end
  end
end
