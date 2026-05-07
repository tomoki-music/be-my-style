require "rails_helper"

RSpec.describe Singing::SeasonBadgeAwarder do
  let(:season) do
    FactoryBot.create(
      :singing_ranking_season,
      starts_on: Date.new(2026, 5, 1),
      ends_on: Date.new(2026, 5, 31),
      status: "active"
    )
  end

  let(:customer_a) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:customer_b) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:customer_c) { FactoryBot.create(:customer, domain_name: "singing") }

  def create_overall_entry(season:, customer:, rank:, score:)
    FactoryBot.create(
      :singing_season_ranking_entry,
      singing_ranking_season: season,
      customer: customer,
      category: "overall",
      rank: rank,
      score: score
    )
  end

  describe ".call" do
    context "順位バッジと参加バッジ" do
      before do
        create_overall_entry(season: season, customer: customer_a, rank: 1, score: 95)
        create_overall_entry(season: season, customer: customer_b, rank: 2, score: 85)
        create_overall_entry(season: season, customer: customer_c, rank: 3, score: 75)
      end

      it "1位に monthly_champion / monthly_top_3 / monthly_top_10 / season_participant を付与すること" do
        described_class.call(season)

        badge_types = season.singing_badges.where(customer: customer_a).pluck(:badge_type)
        expect(badge_types).to include("monthly_champion", "monthly_top_3", "monthly_top_10", "season_participant")
      end

      it "2位に monthly_runner_up / monthly_top_3 / monthly_top_10 / season_participant を付与すること" do
        described_class.call(season)

        badge_types = season.singing_badges.where(customer: customer_b).pluck(:badge_type)
        expect(badge_types).to include("monthly_runner_up", "monthly_top_3", "monthly_top_10", "season_participant")
      end

      it "3位に monthly_top_3 / monthly_top_10 / season_participant を付与すること" do
        described_class.call(season)

        badge_types = season.singing_badges.where(customer: customer_c).pluck(:badge_type)
        expect(badge_types).to include("monthly_top_3", "monthly_top_10", "season_participant")
      end

      it "4〜10位に monthly_top_10 / season_participant を付与すること" do
        customer_d = FactoryBot.create(:customer, domain_name: "singing")
        create_overall_entry(season: season, customer: customer_d, rank: 5, score: 60)

        described_class.call(season)

        badge_types = season.singing_badges.where(customer: customer_d).pluck(:badge_type)
        expect(badge_types).to include("monthly_top_10", "season_participant")
      end

      it "11位以降には season_participant のみ付与すること" do
        customer_e = FactoryBot.create(:customer, domain_name: "singing")
        create_overall_entry(season: season, customer: customer_e, rank: 11, score: 50)

        described_class.call(season)

        expect(season.singing_badges.where(customer: customer_e).pluck(:badge_type)).to eq ["season_participant"]
      end
    end

    context "べき等性（再実行）" do
      it "同一 season に2回実行してもバッジが重複しないこと" do
        create_overall_entry(season: season, customer: customer_a, rank: 1, score: 90)

        described_class.call(season)
        expect { described_class.call(season) }.not_to raise_error

        expect(season.singing_badges.where(customer: customer_a, badge_type: "monthly_champion").count).to eq 1
      end
    end
  end
end
