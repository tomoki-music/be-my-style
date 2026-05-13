require 'rails_helper'

RSpec.describe Singing::GrowthTimelineService do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other_customer) { FactoryBot.create(:customer, domain_name: "singing") }

  describe ".call" do
    it "診断・スコア成長・AIチャレンジ・バッジを新しい順で最大10件返すこと" do
      now = Time.zone.local(2026, 7, 10, 12, 0, 0)
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        created_at: now - 2.months,
        diagnosed_at: now - 2.months,
        overall_score: 70,
        rhythm_score: 62,
        pitch_score: 70,
        expression_score: 70
      )
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        created_at: now - 1.month,
        diagnosed_at: now - 1.month,
        overall_score: 78,
        rhythm_score: 70,
        pitch_score: 69,
        expression_score: 72
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "rhythm",
        challenge_month: (now - 1.month).to_date.beginning_of_month,
        tried: true,
        completed: true,
        completed_at: now - 20.days,
        created_at: now - 45.days,
        updated_at: now - 20.days
      )
      FactoryBot.create_list(
        :singing_diagnosis,
        9,
        :completed,
        customer: customer,
        created_at: now - 4.months,
        diagnosed_at: now - 4.months,
        overall_score: 60
      )

      events = described_class.call(customer)

      expect(events.size).to eq 10
      expect(events.map(&:occurred_at)).to eq(events.map(&:occurred_at).sort.reverse)
      expect(events.map(&:title)).to include(
        "総合スコア +8点成長",
        "リズムスコア +8点成長",
        "リズムチャレンジ完了",
        "リズムチャレンジ達成バッジ獲得"
      )
    end

    it "current_customer以外の診断とprogressを参照しないこと" do
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: other_customer,
        song_title: "Other Singing",
        overall_score: 99,
        rhythm_score: 99
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: other_customer,
        target_key: "rhythm",
        tried: true,
        completed: true
      )

      events = described_class.call(customer)

      expect(events).to be_empty
    end

    it "nilスコアや前回データ不足があっても落ちずに診断完了イベントを返すこと" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        overall_score: nil,
        pitch_score: nil,
        rhythm_score: nil,
        expression_score: nil
      )

      events = described_class.call(customer)

      expect(events.map(&:title)).to include("#{diagnosis.performance_type_label}診断完了")
    end
  end
end
