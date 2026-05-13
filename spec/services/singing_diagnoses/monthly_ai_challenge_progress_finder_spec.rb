require "rails_helper"

RSpec.describe SingingDiagnoses::MonthlyAiChallengeProgressFinder do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:reference_time) { Time.zone.local(2026, 5, 13, 12, 0, 0) }
  let(:challenge) { { target_key: "rhythm" } }

  def finder
    described_class.new(customer, challenge: challenge, reference_time: reference_time)
  end

  it "当月1日のchallenge_monthでprogressを探すこと" do
    progress = finder.find_or_initialize

    expect(progress.challenge_month).to eq Date.new(2026, 5, 1)
  end

  it "target_keyがMonthlyAiChallenge由来になること" do
    progress = finder.find_or_initialize

    expect(progress.target_key).to eq "rhythm"
  end

  it "show用では不要にDB作成しないこと" do
    expect { finder.find_or_initialize }.not_to change(SingingAiChallengeProgress, :count)
  end

  it "update用では必要時に作成すること" do
    expect { finder.find_or_create! }.to change(SingingAiChallengeProgress, :count).by(1)
  end

  it "既存progressがあれば返すこと" do
    existing = FactoryBot.create(
      :singing_ai_challenge_progress,
      customer: customer,
      challenge_month: Date.new(2026, 5, 1),
      target_key: "rhythm"
    )

    expect(finder.find_or_create!).to eq existing
  end
end
