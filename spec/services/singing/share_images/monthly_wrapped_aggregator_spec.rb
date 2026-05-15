require "rails_helper"

RSpec.describe Singing::ShareImages::MonthlyWrappedAggregator, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:reference_time) { Time.zone.local(2026, 5, 15, 12, 0, 0) }

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

  context "当月に診断がある場合" do
    before do
      create_diagnosis(70, Time.zone.local(2026, 5, 1, 10, 0, 0), pitch_score: 65, rhythm_score: 68, expression_score: 60)
      create_diagnosis(80, Time.zone.local(2026, 5, 10, 10, 0, 0), pitch_score: 78, rhythm_score: 72, expression_score: 70)
      create_diagnosis(88, Time.zone.local(2026, 5, 14, 10, 0, 0), pitch_score: 85, rhythm_score: 80, expression_score: 75)
    end

    it "diagnosis_count / best_score を正しく集計すること" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.diagnosis_count).to eq(3)
      expect(stats.best_score).to eq(88)
    end

    it "year / month を返すこと" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.year).to eq(2026)
      expect(stats.month).to eq(5)
    end

    it "前月データなしのときは score_improvement が nil になること" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.prev_avg_score).to be_nil
      expect(stats.score_improvement).to be_nil
    end

    context "前月にも診断がある場合" do
      before do
        create_diagnosis(60, Time.zone.local(2026, 4, 10, 10, 0, 0), pitch_score: 55, rhythm_score: 58, expression_score: 52)
        create_diagnosis(70, Time.zone.local(2026, 4, 20, 10, 0, 0), pitch_score: 65, rhythm_score: 62, expression_score: 60)
      end

      it "score_improvement が今月平均 - 前月平均になること" do
        stats = described_class.call(customer, reference_time: reference_time)

        curr_avg = ((70 + 80 + 88) / 3.0).round(1)
        prev_avg = ((60 + 70) / 2.0).round(1)
        expect(stats.score_improvement).to eq((curr_avg - prev_avg).round(1))
      end

      it "最も伸びたスキルを返すこと" do
        stats = described_class.call(customer, reference_time: reference_time)

        expect(stats.top_skill_label).to be_present
        expect(%w[Pitch Rhythm Expression]).to include(stats.top_skill_label)
        expect(stats.top_skill_delta).to be_a(Numeric)
      end
    end
  end

  context "当月に診断がない場合" do
    before do
      create_diagnosis(75, Time.zone.local(2026, 4, 10, 10, 0, 0))
    end

    it "nil を返すこと" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats).to be_nil
    end
  end

  context "他ユーザーのデータを混ぜないこと" do
    before do
      create_diagnosis(99, Time.zone.local(2026, 5, 10, 10, 0, 0), customer: other_customer)
    end

    it "対象 customer の診断のみ集計すること" do
      create_diagnosis(50, Time.zone.local(2026, 5, 1, 10, 0, 0))

      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.diagnosis_count).to eq(1)
      expect(stats.best_score).to eq(50)
    end

    it "他ユーザーのみ診断がある月は nil を返すこと" do
      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats).to be_nil
    end
  end

  context "challenge_completed_count / challenge_streak" do
    before do
      create_diagnosis(70, Time.zone.local(2026, 5, 10, 10, 0, 0))
    end

    it "当月の challenge 完了数を返すこと" do
      create_challenge_progress(Date.new(2026, 5, 1))
      create_challenge_progress(Date.new(2026, 5, 2))
      create_challenge_progress(Date.new(2026, 5, 3))

      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.challenge_completed_count).to eq(3)
    end

    it "他ユーザーの challenge を混ぜないこと" do
      create_challenge_progress(Date.new(2026, 5, 1), customer: other_customer)

      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.challenge_completed_count).to eq(0)
    end

    it "連続達成ストリークを返すこと" do
      create_challenge_progress(Date.new(2026, 5, 13))
      create_challenge_progress(Date.new(2026, 5, 14))
      create_challenge_progress(Date.new(2026, 5, 15))

      stats = described_class.call(customer, reference_time: reference_time)

      expect(stats.challenge_streak).to eq(3)
    end
  end

  context "customer が nil の場合" do
    it "nil を返すこと" do
      expect(described_class.call(nil, reference_time: reference_time)).to be_nil
    end
  end

  def create_challenge_progress(date, customer: self.customer)
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
