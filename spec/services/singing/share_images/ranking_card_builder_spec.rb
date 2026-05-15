require "rails_helper"

RSpec.describe Singing::ShareImages::RankingCardBuilder, type: :service do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other_customer) { FactoryBot.create(:customer, domain_name: "singing") }

  it "current_customerの自己ベスト診断と現在順位を表示データにすること" do
    FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: other_customer, overall_score: 92)
    FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer, overall_score: 88)
    FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer, overall_score: 72)

    card = described_class.call(customer)

    expect(card.rank).to eq(2)
    expect(card.score).to eq(88)
    expect(card.rank_label).to eq("全国2位")
    expect(card.score_label).to eq("総合スコア 88点")
    expect(card.message).to eq("挑戦の成果がランキングに刻まれました")
    expect(card.badge_label).to eq("Singing Ranking")
    expect(card.x_share_text).to include("現在 全国2位")
    expect(card.x_share_text).not_to include("92")
  end

  it "ranking未参加でも落ちずに自然な表示データを返すこと" do
    FactoryBot.create(:singing_diagnosis, :completed, customer: other_customer, overall_score: 99)

    card = described_class.call(customer)

    expect(card.rank).to be_nil
    expect(card.score).to be_nil
    expect(card.rank_label).to eq("ランキング参加前")
    expect(card.score_label).to eq("次の診断でスコアを記録")
    expect(card.message).to eq("次の挑戦でランキングに参加できます")
  end

  it "取れる場合は直近シーズンの順位推移を返すこと" do
    previous_season = FactoryBot.create(:singing_ranking_season, :closed, ends_on: 1.month.ago.to_date.end_of_month)
    current_season = FactoryBot.create(:singing_ranking_season, :current)
    FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer, overall_score: 80)
    FactoryBot.create(:singing_season_ranking_entry, singing_ranking_season: previous_season, customer: customer, rank: 7, score: 78)
    FactoryBot.create(:singing_season_ranking_entry, singing_ranking_season: current_season, customer: customer, rank: 4, score: 80)

    card = described_class.call(customer)

    expect(card.rank_change).to eq(3)
    expect(card.rank_change_label).to eq("前回より3位アップ")
  end
end
