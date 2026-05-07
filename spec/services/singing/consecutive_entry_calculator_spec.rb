require "rails_helper"

RSpec.describe Singing::ConsecutiveEntryCalculator, type: :service do
  let(:season_1) do
    FactoryBot.create(
      :singing_ranking_season,
      starts_on: Date.new(2026, 3, 1),
      ends_on: Date.new(2026, 3, 31),
      status: "closed"
    )
  end

  let(:season_2) do
    FactoryBot.create(
      :singing_ranking_season,
      starts_on: Date.new(2026, 4, 1),
      ends_on: Date.new(2026, 4, 30),
      status: "closed"
    )
  end

  let(:season_3) do
    FactoryBot.create(
      :singing_ranking_season,
      starts_on: Date.new(2026, 5, 1),
      ends_on: Date.new(2026, 5, 31),
      status: "closed"
    )
  end

  def create_entry(season:, customer:, rank: 1)
    FactoryBot.create(
      :singing_season_ranking_entry,
      singing_ranking_season: season,
      customer: customer,
      category: "overall",
      score: 80,
      rank: rank
    )
  end

  it "指定回数以上の連続参加を判定すること" do
    customer = FactoryBot.create(:customer, domain_name: "singing")
    create_entry(season: season_1, customer: customer)
    create_entry(season: season_2, customer: customer)
    create_entry(season: season_3, customer: customer)

    result = described_class.call(season_3.id).first

    expect(result.customer).to eq customer
    expect(result.count).to eq 3
  end

  it "非連続のユーザーを除外すること" do
    continuous_customer = FactoryBot.create(:customer, domain_name: "singing")
    skipped_customer = FactoryBot.create(:customer, domain_name: "singing")
    create_entry(season: season_1, customer: continuous_customer, rank: 1)
    create_entry(season: season_2, customer: continuous_customer, rank: 1)
    create_entry(season: season_3, customer: continuous_customer, rank: 1)
    create_entry(season: season_1, customer: skipped_customer, rank: 2)
    create_entry(season: season_3, customer: skipped_customer, rank: 2)

    results = described_class.call(season_3.id)

    expect(results.map(&:customer)).to eq [continuous_customer]
  end
end
