require "rails_helper"

RSpec.describe Singing::AwardSeasonBadgesJob, type: :job do
  describe "#perform" do
    it "season_id を渡すと SeasonBadgeAwarder が呼ばれること" do
      season = FactoryBot.create(:singing_ranking_season)
      expect(Singing::SeasonBadgeAwarder).to receive(:call).with(season)

      described_class.perform_now(season.id)
    end

    it "存在しない season_id は ActiveRecord::RecordNotFound になること" do
      expect {
        described_class.perform_now(-1)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
