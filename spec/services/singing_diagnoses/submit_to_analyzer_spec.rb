require 'rails_helper'

RSpec.describe SingingDiagnoses::SubmitToAnalyzer do
  describe ".call" do
    it "queuedの診断をprocessingにしてclientへ渡し結果を保存すること" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :queued)
      client = instance_double(SingingDiagnoses::AnalyzerClient)
      payload = {
        overall_score: 86,
        pitch_score: 82,
        rhythm_score: 90,
        expression_score: 84
      }

      expect(client).to receive(:submit).with(diagnosis).and_return(payload)

      expect(described_class.call(diagnosis, client: client)).to eq true

      diagnosis.reload
      expect(diagnosis).to be_completed
      expect(diagnosis.overall_score).to eq 86
      expect(diagnosis.failure_reason).to be_blank
    end

    it "queued以外は送信しないこと" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :processing)
      client = instance_double(SingingDiagnoses::AnalyzerClient)

      expect(client).not_to receive(:submit)

      expect(described_class.call(diagnosis, client: client)).to eq false
      expect(diagnosis.reload).to be_processing
    end

    it "clientで予期しない例外が起きた場合はfailedにしてユーザー向けメッセージを保存すること" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :queued)
      client = instance_double(SingingDiagnoses::AnalyzerClient)

      allow(client).to receive(:submit).and_raise(StandardError, "unexpected!")

      expect(described_class.call(diagnosis, client: client)).to eq false
      expect(diagnosis.reload).to be_failed
      expect(diagnosis.failure_reason).to eq described_class::GENERIC_FAILURE_MESSAGE
    end

    it "ConnectionErrorが起きた場合はユーザー向けメッセージをfailure_reasonに保存すること" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :queued)
      client = instance_double(SingingDiagnoses::AnalyzerClient)
      user_message = SingingDiagnoses::AnalyzerClient::USER_FACING_CONNECTION_ERROR

      allow(client).to receive(:submit).and_raise(
        SingingDiagnoses::AnalyzerClient::ConnectionError, user_message
      )

      expect(described_class.call(diagnosis, client: client)).to eq false
      expect(diagnosis.reload).to be_failed
      expect(diagnosis.failure_reason).to eq user_message
    end

    it "結果payloadが不正な場合はfailedにすること" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :queued)
      client = instance_double(SingingDiagnoses::AnalyzerClient)

      allow(client).to receive(:submit).and_return({ overall_score: 80 })

      expect(described_class.call(diagnosis, client: client)).to eq false
      expect(diagnosis.reload).to be_failed
      expect(diagnosis.failure_reason).to eq "Invalid analyzer payload"
    end
  end
end
