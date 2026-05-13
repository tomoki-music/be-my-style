require "rails_helper"

RSpec.describe SingingAiChallengeProgress, type: :model do
  it "valid factoryが作れること" do
    progress = FactoryBot.build(:singing_ai_challenge_progress)

    expect(progress).to be_valid
  end

  it "customer必須であること" do
    progress = FactoryBot.build(:singing_ai_challenge_progress, customer: nil)

    expect(progress).not_to be_valid
  end

  it "target_key必須であること" do
    progress = FactoryBot.build(:singing_ai_challenge_progress, target_key: nil)

    expect(progress).not_to be_valid
  end

  it "challenge_month必須であること" do
    progress = FactoryBot.build(:singing_ai_challenge_progress, challenge_month: nil)

    expect(progress).not_to be_valid
  end

  it "target_keyは habit/pitch/rhythm/expression のみ許可すること" do
    expect(FactoryBot.build(:singing_ai_challenge_progress, target_key: "habit")).to be_valid
    expect(FactoryBot.build(:singing_ai_challenge_progress, target_key: "pitch")).to be_valid
    expect(FactoryBot.build(:singing_ai_challenge_progress, target_key: "rhythm")).to be_valid
    expect(FactoryBot.build(:singing_ai_challenge_progress, target_key: "expression")).to be_valid
    expect(FactoryBot.build(:singing_ai_challenge_progress, target_key: "tone")).not_to be_valid
  end

  it "customer_id + challenge_month + target_key がuniqueであること" do
    existing = FactoryBot.create(:singing_ai_challenge_progress)
    duplicate = FactoryBot.build(
      :singing_ai_challenge_progress,
      customer: existing.customer,
      challenge_month: existing.challenge_month,
      target_key: existing.target_key
    )

    expect(duplicate).not_to be_valid
  end

  it "completed true 時に completed_at を設定すること" do
    progress = FactoryBot.create(:singing_ai_challenge_progress, completed: false, completed_at: nil)

    progress.update!(completed: true)

    expect(progress.completed_at).to be_present
  end

  it "completed false 時に completed_at をクリアすること" do
    progress = FactoryBot.create(:singing_ai_challenge_progress, completed: true)

    progress.update!(completed: false)

    expect(progress.completed_at).to be_nil
  end
end
