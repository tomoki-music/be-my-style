require "rails_helper"

RSpec.describe Singing::ShareImages::DailyChallengeCardBuilder, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:reference_time) { Time.zone.local(2026, 5, 15, 12, 0, 0) }

  around do |example|
    travel_to(reference_time) { example.run }
  end

  before do
    FactoryBot.create(:singing_daily_challenge, challenge_date: Date.current)
  end

  it "streakとcompleted_todayを表示用データにすること" do
    create_progress_for(Date.current - 2.days)
    create_progress_for(Date.current - 1.day)
    create_progress_for(Date.current)

    card = described_class.call(customer, reference_time: reference_time)

    expect(card.streak_days).to eq(3)
    expect(card.completed_today).to eq(true)
    expect(card.headline).to eq("3日継続中")
    expect(card.subheadline).to eq("今日も歌の練習を完了しました")
  end

  it "score_deltaがpositiveの場合は小さな成長として整形すること" do
    FactoryBot.create(:singing_diagnosis, :completed, customer: customer, created_at: 1.day.ago, overall_score: 70)
    FactoryBot.create(:singing_diagnosis, :completed, customer: customer, created_at: Time.current, overall_score: 74)
    create_progress_for(Date.current)

    card = described_class.call(customer, reference_time: reference_time)

    expect(card.score_delta).to eq(4)
    expect(card.score_delta_label).to eq("+4点")
    expect(card.message).to eq("前回より少し前に進みました")
    expect(card.x_share_text).to include("前回より +4点アップ")
  end

  it "score_deltaがnilでも落ちずに自然な表示にすること" do
    FactoryBot.create(:singing_diagnosis, :completed, customer: customer, created_at: Time.current, overall_score: 74)
    create_progress_for(Date.current)

    card = described_class.call(customer, reference_time: reference_time)

    expect(card.score_delta).to be_nil
    expect(card.score_delta_label).to be_nil
    expect(card.message).to eq("小さな一歩を積み重ねています")
  end

  it "未挑戦でも落ちないこと" do
    card = described_class.call(customer, reference_time: reference_time)

    expect(card.completed_today).to eq(false)
    expect(card.streak_days).to eq(0)
    expect(card.headline).to eq("今日の一歩を準備中")
    expect(card.x_share_text).to include("Daily Challengeに挑戦中")
  end

  it "他ユーザーのprogressや診断を混ぜないこと" do
    other_customer = FactoryBot.create(:customer, domain_name: "singing")
    FactoryBot.create(:singing_diagnosis, :completed, customer: other_customer, created_at: 1.day.ago, overall_score: 60)
    FactoryBot.create(:singing_diagnosis, :completed, customer: other_customer, created_at: Time.current, overall_score: 90)
    create_progress_for(Date.current, customer: other_customer)

    card = described_class.call(customer, reference_time: reference_time)

    expect(card.completed_today).to eq(false)
    expect(card.streak_days).to eq(0)
    expect(card.score_delta).to be_nil
  end

  def create_progress_for(date, customer: self.customer)
    challenge = SingingDailyChallenge.find_or_create_by!(challenge_date: date) do |daily_challenge|
      daily_challenge.challenge_type = "count"
      daily_challenge.target_attribute = "overall"
      daily_challenge.threshold_value = 1
      daily_challenge.xp_reward = 20
      daily_challenge.title = "今日1回診断してみよう！"
      daily_challenge.description = "1回でも診断を完了させよう。"
    end

    FactoryBot.create(
      :singing_daily_challenge_progress,
      customer: customer,
      singing_daily_challenge: challenge,
      completed_at: date.in_time_zone.change(hour: 12)
    )
  end
end
