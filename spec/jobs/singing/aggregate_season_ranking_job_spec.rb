require 'rails_helper'

RSpec.describe Singing::AggregateSeasonRankingJob, type: :job do
  describe "#perform" do
    it "season id を渡すと entries が作成されること" do
      season = FactoryBot.create(
        :singing_ranking_season,
        starts_on: Date.new(2026, 5, 1),
        ends_on: Date.new(2026, 5, 31),
        status: "active"
      )
      customer = FactoryBot.create(:customer, domain_name: "singing")
      FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        overall_score: 88
      )
      allow(Singing::AwardSeasonBadgesJob).to receive(:perform_later)

      expect {
        described_class.perform_now(season.id)
      }.to change(SingingSeasonRankingEntry, :count).by(4)

      expect(Singing::AwardSeasonBadgesJob).to have_received(:perform_later).with(season.id)
    end

    it "存在しない season id は ActiveRecord::RecordNotFound になること" do
      expect {
        described_class.perform_now(-1)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
