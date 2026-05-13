require 'rails_helper'

RSpec.describe Singing::ChallengeBadgeService do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other_customer) { FactoryBot.create(:customer, domain_name: "singing") }

  describe ".call" do
    it "完了したAIチャレンジとスコア差分から達成バッジを返すこと" do
      previous_diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        created_at: 10.days.ago,
        rhythm_score: 70
      )
      progress = FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "rhythm",
        challenge_month: previous_diagnosis.created_at.to_date.beginning_of_month,
        tried: true,
        completed: true,
        created_at: 8.days.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        created_at: Time.current,
        rhythm_score: 81
      )
      feedback = {
        progress: progress,
        previous_diagnosis: previous_diagnosis,
        target_key: "rhythm",
        delta: 11
      }

      result = described_class.call(customer, diagnosis, feedback: feedback)

      expect(result.earned_badges.map(&:key)).to include(
        :rhythm_challenge_completed,
        :first_ai_challenge_completed,
        :growth_plus_5,
        :growth_plus_10
      )
      expect(result.candidate_badges.map(&:key)).to include(:three_consecutive_diagnoses)
    end

    it "チャレンジ未完了で伸び幅が閾値未満の場合は獲得候補バッジを返すこと" do
      previous_diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        created_at: 10.days.ago,
        pitch_score: 70
      )
      progress = FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "pitch",
        tried: true,
        completed: false,
        created_at: 8.days.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        created_at: Time.current,
        pitch_score: 73
      )
      feedback = {
        progress: progress,
        previous_diagnosis: previous_diagnosis,
        target_key: "pitch",
        delta: 3
      }

      result = described_class.call(customer, diagnosis, feedback: feedback)

      expect(result.earned_badges).to be_empty
      expect(result.candidate_badges.map(&:key)).to include(
        :pitch_challenge_completed,
        :growth_plus_5,
        :growth_plus_10
      )
      expect(result.candidate_badges.find { |badge| badge.key == :growth_plus_5 }.description).to eq "あと2点アップで獲得できます。"
    end

    it "同じ診断対象で3回目の診断なら3回連続診断バッジを返すこと" do
      FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, performance_type: :vocal, created_at: 20.days.ago)
      previous_diagnosis = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, performance_type: :vocal, created_at: 10.days.ago)
      progress = FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "expression",
        completed: true,
        created_at: 8.days.ago
      )
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, performance_type: :vocal, created_at: Time.current)

      result = described_class.call(
        customer,
        diagnosis,
        feedback: { progress: progress, previous_diagnosis: previous_diagnosis, target_key: "expression", delta: 0 }
      )

      expect(result.earned_badges.map(&:key)).to include(:three_consecutive_diagnoses)
    end

    it "前回診断がない場合はnilを返すこと" do
      progress = FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "rhythm",
        tried: true,
        completed: true,
        created_at: 8.days.ago
      )
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: Time.current)

      expect(described_class.call(customer, diagnosis, feedback: { progress: progress, delta: 5 })).to be_nil
    end

    it "challenge progressがない場合はnilを返すこと" do
      FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: 10.days.ago)
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: Time.current)

      expect(described_class.call(customer, diagnosis)).to be_nil
    end

    it "current_customer以外のprogressを参照しないこと" do
      FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: 10.days.ago)
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: other_customer,
        target_key: "rhythm",
        tried: true,
        completed: true,
        created_at: 8.days.ago
      )
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: Time.current)

      expect(described_class.call(customer, diagnosis)).to be_nil
    end
  end
end
