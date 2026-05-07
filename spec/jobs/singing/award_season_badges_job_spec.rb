require "rails_helper"

RSpec.describe Singing::AwardSeasonBadgesJob, type: :job do
  let(:season) do
    FactoryBot.create(
      :singing_ranking_season,
      starts_on: Date.new(2026, 5, 1),
      ends_on: Date.new(2026, 5, 31),
      status: "closed"
    )
  end

  def create_overall_entry(rank:)
    FactoryBot.create(
      :singing_season_ranking_entry,
      singing_ranking_season: season,
      customer: FactoryBot.create(:customer, domain_name: "singing"),
      category: "overall",
      rank: rank,
      score: 100 - rank
    )
  end

  def create_entry(season:, customer:, rank:, score:)
    FactoryBot.create(
      :singing_season_ranking_entry,
      singing_ranking_season: season,
      customer: customer,
      category: "overall",
      rank: rank,
      score: score
    )
  end

  def badge_types_for(entry)
    season.singing_badges.where(customer: entry.customer).pluck(:badge_type)
  end

  describe "#perform" do
    it "1位に monthly_champion が付与されること" do
      entry = create_overall_entry(rank: 1)

      described_class.perform_now(season.id)

      expect(badge_types_for(entry)).to include("monthly_champion")
    end

    it "2位に monthly_runner_up が付与されること" do
      entry = create_overall_entry(rank: 2)

      described_class.perform_now(season.id)

      expect(badge_types_for(entry)).to include("monthly_runner_up")
    end

    it "3位以内に monthly_top_3 が付与されること" do
      entries = [1, 2, 3].map { |rank| create_overall_entry(rank: rank) }

      described_class.perform_now(season.id)

      entries.each do |entry|
        expect(badge_types_for(entry)).to include("monthly_top_3")
      end
    end

    it "10位以内に monthly_top_10 が付与されること" do
      entries = [1, 2, 3, 10].map { |rank| create_overall_entry(rank: rank) }

      described_class.perform_now(season.id)

      entries.each do |entry|
        expect(badge_types_for(entry)).to include("monthly_top_10")
      end
    end

    it "参加者全員に season_participant が付与されること" do
      entries = [1, 2, 3, 10, 11].map { |rank| create_overall_entry(rank: rank) }

      described_class.perform_now(season.id)

      entries.each do |entry|
        expect(badge_types_for(entry)).to include("season_participant")
      end
    end

    it "同じJobを2回実行しても重複付与されないこと" do
      entry = create_overall_entry(rank: 1)

      described_class.perform_now(season.id)

      expect {
        described_class.perform_now(season.id)
      }.not_to change { season.singing_badges.where(customer: entry.customer).count }
    end

    it "growth_singer が付与されること" do
      previous_season = FactoryBot.create(
        :singing_ranking_season,
        starts_on: Date.new(2026, 4, 1),
        ends_on: Date.new(2026, 4, 30),
        status: "closed"
      )
      customer = FactoryBot.create(:customer, domain_name: "singing")
      create_entry(season: previous_season, customer: customer, rank: 1, score: 70)
      create_entry(season: season, customer: customer, rank: 1, score: 90)

      described_class.perform_now(season.id)

      expect(season.singing_badges.where(customer: customer).pluck(:badge_type)).to include("growth_singer")
    end

    it "consecutive_entry が付与されること" do
      season_1 = FactoryBot.create(
        :singing_ranking_season,
        starts_on: Date.new(2026, 3, 1),
        ends_on: Date.new(2026, 3, 31),
        status: "closed"
      )
      season_2 = FactoryBot.create(
        :singing_ranking_season,
        starts_on: Date.new(2026, 4, 1),
        ends_on: Date.new(2026, 4, 30),
        status: "closed"
      )
      customer = FactoryBot.create(:customer, domain_name: "singing")
      create_entry(season: season_1, customer: customer, rank: 1, score: 70)
      create_entry(season: season_2, customer: customer, rank: 1, score: 80)
      create_entry(season: season, customer: customer, rank: 1, score: 90)

      described_class.perform_now(season.id)

      expect(season.singing_badges.where(customer: customer).pluck(:badge_type)).to include("consecutive_entry")
    end

    it "growth_singer と consecutive_entry が重複付与されないこと" do
      season_1 = FactoryBot.create(
        :singing_ranking_season,
        starts_on: Date.new(2026, 3, 1),
        ends_on: Date.new(2026, 3, 31),
        status: "closed"
      )
      season_2 = FactoryBot.create(
        :singing_ranking_season,
        starts_on: Date.new(2026, 4, 1),
        ends_on: Date.new(2026, 4, 30),
        status: "closed"
      )
      customer = FactoryBot.create(:customer, domain_name: "singing")
      create_entry(season: season_1, customer: customer, rank: 1, score: 70)
      create_entry(season: season_2, customer: customer, rank: 1, score: 80)
      create_entry(season: season, customer: customer, rank: 1, score: 95)

      described_class.perform_now(season.id)

      expect {
        described_class.perform_now(season.id)
      }.not_to change {
        season.singing_badges.where(customer: customer, badge_type: %w[growth_singer consecutive_entry]).count
      }
    end

    it "存在しない season_id でも致命的エラーにならないこと" do
      expect {
        described_class.perform_now(-1)
      }.not_to raise_error
    end
  end
end
