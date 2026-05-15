require "rails_helper"

RSpec.describe Singing::ShareImages::YearlyWrappedAggregator, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:reference_time) { Time.zone.local(2026, 6, 15, 12, 0, 0) }

  around do |example|
    travel_to(reference_time) { example.run }
  end

  def create_diagnosis(score, created_at, customer: self.customer, **attrs)
    FactoryBot.create(
      :singing_diagnosis,
      :completed,
      customer: customer,
      created_at: created_at,
      overall_score: score,
      **attrs
    )
  end

  context "当年に診断がある場合" do
    before do
      create_diagnosis(70, Time.zone.local(2026, 1, 10, 10, 0, 0), pitch_score: 60, rhythm_score: 65, expression_score: 58)
      create_diagnosis(80, Time.zone.local(2026, 4, 15, 10, 0, 0), pitch_score: 72, rhythm_score: 70, expression_score: 65)
      create_diagnosis(88, Time.zone.local(2026, 6, 10, 10, 0, 0), pitch_score: 82, rhythm_score: 78, expression_score: 74)
    end

    it "Stats Struct を返すこと" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats).to be_a(described_class::Stats)
    end

    it "year / diagnosis_count / best_score を正しく返すこと" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.year).to eq(2026)
      expect(stats.diagnosis_count).to eq(3)
      expect(stats.best_score).to eq(88)
    end

    it "avg_score を正しく計算すること" do
      stats = described_class.call(customer, reference_time: reference_time)

      expected = ((70 + 80 + 88) / 3.0).round(1)
      expect(stats.avg_score).to eq(expected)
    end

    it "score_growth が年初→年末の delta になること" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.score_growth).to eq(88 - 70)
    end

    it "top_month が最も診断回数の多い月を返すこと" do
      create_diagnosis(75, Time.zone.local(2026, 4, 20, 10, 0, 0))

      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.top_month).to eq(4)
      expect(stats.top_month_count).to eq(2)
    end

    it "top_skill_label が最も伸びたスキルを返すこと" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.top_skill_label).to be_present
      expect(%w[Pitch Rhythm Expression]).to include(stats.top_skill_label)
      expect(stats.top_skill_delta).to be_positive
    end
  end

  context "診断が1回のみの場合" do
    before do
      create_diagnosis(80, Time.zone.local(2026, 3, 10, 10, 0, 0))
    end

    it "score_growth が nil になること（比較不可）" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.score_growth).to be_nil
    end

    it "top_skill_delta が nil になること（比較不可）" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.top_skill_label).to be_nil
      expect(stats.top_skill_delta).to be_nil
    end
  end

  context "当年に診断がない場合" do
    before do
      create_diagnosis(75, Time.zone.local(2025, 12, 10, 10, 0, 0))
    end

    it "nil を返すこと" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats).to be_nil
    end
  end

  context "他ユーザーのデータを混ぜないこと" do
    before do
      create_diagnosis(99, Time.zone.local(2026, 3, 10, 10, 0, 0), customer: other_customer)
    end

    it "対象 customer の診断のみ集計すること" do
      create_diagnosis(50, Time.zone.local(2026, 2, 1, 10, 0, 0))

      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.diagnosis_count).to eq(1)
      expect(stats.best_score).to eq(50)
    end

    it "他ユーザーのみ診断がある年は nil を返すこと" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats).to be_nil
    end
  end

  context "ai_challenge_count の集計" do
    before do
      create_diagnosis(70, Time.zone.local(2026, 5, 10, 10, 0, 0))
    end

    it "当年の AIチャレンジ挑戦回数を返すこと" do
      3.times do |i|
        FactoryBot.create(
          :singing_ai_challenge_progress,
          customer: customer,
          target_key: "pitch",
          challenge_month: Date.new(2026, i + 1, 1),
          tried: true
        )
      end

      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.ai_challenge_count).to eq(3)
    end

    it "前年のチャレンジを混ぜないこと" do
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "pitch",
        challenge_month: Date.new(2025, 12, 1),
        tried: true
      )

      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.ai_challenge_count).to eq(0)
    end
  end

  context "longest_challenge_streak の集計" do
    before do
      create_diagnosis(70, Time.zone.local(2026, 5, 10, 10, 0, 0))
    end

    it "最長連続チャレンジ日数を返すこと" do
      [
        Date.new(2026, 5, 1),
        Date.new(2026, 5, 2),
        Date.new(2026, 5, 3),
        Date.new(2026, 5, 10),
        Date.new(2026, 5, 11)
      ].each { |d| create_daily_challenge_progress(d) }

      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.longest_challenge_streak).to eq(3)
    end

    it "Daily Challenge 記録がない場合は 0 を返すこと" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.longest_challenge_streak).to eq(0)
    end
  end

  context "customer が nil の場合" do
    it "nil を返すこと" do
      expect(described_class.call(nil, reference_time: reference_time)).to be_nil
    end
  end

  def create_daily_challenge_progress(date, customer: self.customer)
    challenge = SingingDailyChallenge.find_or_create_by!(challenge_date: date) do |c|
      c.challenge_type = "count"
      c.target_attribute = "overall"
      c.threshold_value = 1
      c.xp_reward = 20
      c.title = "テストチャレンジ"
      c.description = "1回診断してみよう。"
    end

    FactoryBot.create(
      :singing_daily_challenge_progress,
      customer: customer,
      singing_daily_challenge: challenge,
      completed_at: date.in_time_zone.change(hour: 12)
    )
  end
end
