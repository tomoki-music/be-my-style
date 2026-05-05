require "rails_helper"

RSpec.describe Singing::CurrentRankingSeasonEnsurer do
  describe "#call" do
    let(:target_date) { Date.new(2026, 5, 15) }

    it "当月seasonがない場合、作成されること" do
      expect {
        described_class.new(target_date).call
      }.to change(SingingRankingSeason, :count).by(1)
    end

    it "作成される name / starts_on / ends_on / status / season_type が正しいこと" do
      result = described_class.new(target_date).call
      season = result[:season]

      expect(result[:created]).to be true
      expect(season.name).to eq "2026年5月シーズン"
      expect(season.starts_on).to eq Date.new(2026, 5, 1)
      expect(season.ends_on).to eq Date.new(2026, 5, 31)
      expect(season.status).to eq "active"
      expect(season.season_type).to eq "monthly"
    end

    it "当月seasonがある場合、重複作成されないこと" do
      existing = FactoryBot.create(
        :singing_ranking_season,
        starts_on: Date.new(2026, 5, 1),
        ends_on: Date.new(2026, 5, 31),
        status: "active",
        season_type: "monthly"
      )

      expect {
        result = described_class.new(target_date).call
        expect(result[:created]).to be false
        expect(result[:season]).to eq existing
      }.not_to change(SingingRankingSeason, :count)
    end

    it "draft の同月seasonがある場合も重複作成しないこと" do
      existing = FactoryBot.create(
        :singing_ranking_season,
        :draft,
        starts_on: Date.new(2026, 5, 1),
        ends_on: Date.new(2026, 5, 31),
        season_type: "monthly"
      )

      result = nil
      expect {
        result = described_class.new(target_date).call
      }.not_to change(SingingRankingSeason, :count)
      expect(result[:season]).to eq existing
      expect(result[:created]).to be false
    end

    it "closed の同月seasonがある場合も重複作成しないこと" do
      existing = FactoryBot.create(
        :singing_ranking_season,
        :closed,
        starts_on: Date.new(2026, 5, 1),
        ends_on: Date.new(2026, 5, 31),
        season_type: "monthly"
      )

      result = described_class.new(target_date).call
      expect(result[:season]).to eq existing
      expect(result[:created]).to be false
    end

    it "別月activeが存在しても勝手にclosedへ変更しないこと" do
      previous_active = FactoryBot.create(
        :singing_ranking_season,
        starts_on: Date.new(2026, 4, 1),
        ends_on: Date.new(2026, 4, 30),
        status: "active",
        season_type: "monthly"
      )

      result = described_class.new(target_date).call

      expect(result[:created]).to be true
      expect(previous_active.reload.status).to eq "active"
    end

    it "任意日付を渡して対象月のseasonを作成できること" do
      result = described_class.new(Date.new(2026, 2, 3)).call

      expect(result[:season].name).to eq "2026年2月シーズン"
      expect(result[:season].starts_on).to eq Date.new(2026, 2, 1)
      expect(result[:season].ends_on).to eq Date.new(2026, 2, 28)
    end
  end
end
