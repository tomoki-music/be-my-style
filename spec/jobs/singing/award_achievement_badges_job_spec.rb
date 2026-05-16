require "rails_helper"

RSpec.describe Singing::AwardAchievementBadgesJob, type: :job do
  let(:customer)  { create(:customer, domain_name: "singing") }
  let(:diagnosis) { create(:singing_diagnosis, :completed, customer: customer) }

  describe "#perform" do
    it "calls AwardAchievementBadgesService" do
      expect(Singing::AwardAchievementBadgesService).to receive(:call).with(diagnosis)
      described_class.perform_now(diagnosis.id)
    end

    context "when diagnosis does not exist" do
      it "returns without error" do
        expect { described_class.perform_now(0) }.not_to raise_error
      end
    end

    context "when diagnosis is not completed" do
      let(:diagnosis) { create(:singing_diagnosis, customer: customer, status: :queued) }

      it "does not call service" do
        expect(Singing::AwardAchievementBadgesService).not_to receive(:call)
        described_class.perform_now(diagnosis.id)
      end
    end
  end
end
