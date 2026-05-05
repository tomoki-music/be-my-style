require "rails_helper"

RSpec.describe Singing::EnsureCurrentRankingSeasonJob, type: :job do
  describe "#perform" do
    it "season id を指定せずに当月seasonを作成できること" do
      expect {
        described_class.perform_now(Date.new(2026, 5, 1))
      }.to change(SingingRankingSeason, :count).by(1)
    end

    it "戻り値で作成有無を判別できること" do
      result = described_class.perform_now(Date.new(2026, 5, 1))

      expect(result[:created]).to be true
      expect(result[:season]).to be_a(SingingRankingSeason)
    end

    it "既存seasonがある場合は重複作成しないこと" do
      FactoryBot.create(
        :singing_ranking_season,
        starts_on: Date.new(2026, 5, 1),
        ends_on: Date.new(2026, 5, 31),
        season_type: "monthly"
      )

      expect {
        result = described_class.perform_now(Date.new(2026, 5, 1))
        expect(result[:created]).to be false
      }.not_to change(SingingRankingSeason, :count)
    end
  end
end
