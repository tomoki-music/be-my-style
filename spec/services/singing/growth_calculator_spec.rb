require "rails_helper"

RSpec.describe Singing::GrowthCalculator, type: :service do
  let(:previous_season) do
    FactoryBot.create(
      :singing_ranking_season,
      starts_on: Date.new(2026, 4, 1),
      ends_on: Date.new(2026, 4, 30),
      status: "closed"
    )
  end

  let(:season) do
    FactoryBot.create(
      :singing_ranking_season,
      starts_on: Date.new(2026, 5, 1),
      ends_on: Date.new(2026, 5, 31),
      status: "closed"
    )
  end

  def create_entry(season:, customer:, score:, rank: 1)
    FactoryBot.create(
      :singing_season_ranking_entry,
      singing_ranking_season: season,
      customer: customer,
      category: "overall",
      score: score,
      rank: rank
    )
  end

  it "前シーズンとの差分を成長値として計算すること" do
    customer = FactoryBot.create(:customer, domain_name: "singing")
    create_entry(season: previous_season, customer: customer, score: 70)
    create_entry(season: season, customer: customer, score: 84)

    result = described_class.call(season.id).first

    expect(result.customer).to eq customer
    expect(result.previous_score).to eq 70
    expect(result.score).to eq 84
    expect(result.growth_amount).to eq 14
  end

  it "成長値の降順で上位N名を返すこと" do
    customers = FactoryBot.create_list(:customer, 6, domain_name: "singing")
    growth_values = [3, 18, 9, 25, 12, 6]

    customers.each.with_index do |customer, index|
      create_entry(season: previous_season, customer: customer, score: 60, rank: index + 1)
      create_entry(season: season, customer: customer, score: 60 + growth_values[index], rank: index + 1)
    end

    results = described_class.call(season.id, limit: 3)

    expect(results.map(&:customer)).to eq [customers[3], customers[1], customers[4]]
    expect(results.map(&:growth_amount)).to eq [25, 18, 12]
  end

  it "両シーズンにエントリがあるユーザーのみ対象にすること" do
    returning_customer = FactoryBot.create(:customer, domain_name: "singing")
    new_customer = FactoryBot.create(:customer, domain_name: "singing")
    create_entry(season: previous_season, customer: returning_customer, score: 70, rank: 1)
    create_entry(season: season, customer: returning_customer, score: 80, rank: 1)
    create_entry(season: season, customer: new_customer, score: 99, rank: 2)

    results = described_class.call(season.id)

    expect(results.map(&:customer)).to eq [returning_customer]
  end
end
