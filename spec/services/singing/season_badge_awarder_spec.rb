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
    context "順位バッジ" do
      before do
        create_overall_entry(season: season, customer: customer_a, rank: 1, score: 95)
        create_overall_entry(season: season, customer: customer_b, rank: 2, score: 85)
        create_overall_entry(season: season, customer: customer_c, rank: 3, score: 75)
      end

      it "1位に season_1st バッジを付与すること" do
        described_class.call(season)
        expect(season.singing_badges.find_by(customer: customer_a, badge_type: "season_1st")).to be_present
      end

      it "2位に season_2nd バッジを付与すること" do
        described_class.call(season)
        expect(season.singing_badges.find_by(customer: customer_b, badge_type: "season_2nd")).to be_present
      end

      it "3位に season_top3 バッジを付与すること" do
        described_class.call(season)
        expect(season.singing_badges.find_by(customer: customer_c, badge_type: "season_top3")).to be_present
      end

      it "4〜10位に season_top10 バッジを付与すること" do
        customer_d = FactoryBot.create(:customer, domain_name: "singing")
        create_overall_entry(season: season, customer: customer_d, rank: 5, score: 60)

        described_class.call(season)

        expect(season.singing_badges.find_by(customer: customer_d, badge_type: "season_top10")).to be_present
      end

      it "11位以降にはランキングバッジを付与しないこと" do
        customer_e = FactoryBot.create(:customer, domain_name: "singing")
        create_overall_entry(season: season, customer: customer_e, rank: 11, score: 50)

        described_class.call(season)

        badge_types = SingingBadge::BADGE_TYPES.select { |t| t.start_with?("season_") }
        expect(season.singing_badges.where(customer: customer_e, badge_type: badge_types)).to be_empty
      end
    end

    context "急成長バッジ" do
      let(:prev_season) do
        FactoryBot.create(
          :singing_ranking_season,
          starts_on: Date.new(2026, 4, 1),
          ends_on: Date.new(2026, 4, 30),
          status: "closed"
        )
      end

      before do
        create_overall_entry(season: prev_season, customer: customer_a, rank: 1, score: 60)
        create_overall_entry(season: prev_season, customer: customer_b, rank: 2, score: 50)
        create_overall_entry(season: prev_season, customer: customer_c, rank: 3, score: 40)

        create_overall_entry(season: season, customer: customer_a, rank: 1, score: 90) # +30
        create_overall_entry(season: season, customer: customer_b, rank: 2, score: 75) # +25
        create_overall_entry(season: season, customer: customer_c, rank: 3, score: 55) # +15
      end

      it "前シーズン比で成長幅が大きいTOP3に rapid_growth バッジを付与すること" do
        described_class.call(season)

        [customer_a, customer_b, customer_c].each do |customer|
          expect(season.singing_badges.find_by(customer: customer, badge_type: "rapid_growth")).to be_present
        end
      end

      it "前シーズンに参加していないユーザーは対象外であること" do
        customer_new = FactoryBot.create(:customer, domain_name: "singing")
        create_overall_entry(season: season, customer: customer_new, rank: 4, score: 80)

        described_class.call(season)

        expect(season.singing_badges.find_by(customer: customer_new, badge_type: "rapid_growth")).to be_nil
      end

      it "スコアが下がったユーザーは対象外であること" do
        customer_down = FactoryBot.create(:customer, domain_name: "singing")
        create_overall_entry(season: prev_season, customer: customer_down, rank: 4, score: 90)
        create_overall_entry(season: season, customer: customer_down, rank: 5, score: 70)

        described_class.call(season)

        expect(season.singing_badges.find_by(customer: customer_down, badge_type: "rapid_growth")).to be_nil
      end
    end

    context "継続バッジ" do
      let(:prev_season) do
        FactoryBot.create(
          :singing_ranking_season,
          starts_on: Date.new(2026, 4, 1),
          ends_on: Date.new(2026, 4, 30),
          status: "closed"
        )
      end

      it "前シーズンにも参加したユーザーに consecutive_participation バッジを付与すること" do
        create_overall_entry(season: prev_season, customer: customer_a, rank: 1, score: 80)
        create_overall_entry(season: season, customer: customer_a, rank: 1, score: 85)

        described_class.call(season)

        expect(season.singing_badges.find_by(customer: customer_a, badge_type: "consecutive_participation")).to be_present
      end

      it "前シーズンに参加していないユーザーは対象外であること" do
        create_overall_entry(season: season, customer: customer_b, rank: 1, score: 80)

        described_class.call(season)

        expect(season.singing_badges.find_by(customer: customer_b, badge_type: "consecutive_participation")).to be_nil
      end

      it "前シーズンが存在しない場合は付与しないこと" do
        create_overall_entry(season: season, customer: customer_a, rank: 1, score: 80)

        expect {
          described_class.call(season)
        }.not_to raise_error

        expect(season.singing_badges.where(badge_type: "consecutive_participation")).to be_empty
      end
    end

    context "べき等性（再実行）" do
      it "同一 season に2回実行してもバッジが重複しないこと" do
        create_overall_entry(season: season, customer: customer_a, rank: 1, score: 90)

        described_class.call(season)
        expect { described_class.call(season) }.not_to raise_error

        expect(season.singing_badges.where(customer: customer_a, badge_type: "season_1st").count).to eq 1
      end
    end
  end
end
