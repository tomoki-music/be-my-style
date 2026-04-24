require 'rails_helper'

RSpec.describe SingingDiagnoses::SubmitToAnalyzerJob, type: :job do
  describe "#perform" do
    it "diagnosis idを受け取ってSubmitToAnalyzerを呼ぶこと" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :queued)

      expect(SingingDiagnoses::SubmitToAnalyzer).to receive(:call).with(diagnosis)

      described_class.perform_now(diagnosis.id)
    end

    it "diagnosisが存在しない場合は安全に終了すること" do
      expect(SingingDiagnoses::SubmitToAnalyzer).not_to receive(:call)

      expect { described_class.perform_now(-1) }.not_to raise_error
    end
  end
end
