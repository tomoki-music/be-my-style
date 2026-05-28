require 'rails_helper'

RSpec.describe Singing::GrowthJourneyTimelineBuilder do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }

  describe ".call" do
    it "customerがnilのとき空配列を返すこと" do
      expect(described_class.call(nil)).to eq []
    end

    it "完了済み診断がないとき空配列を返すこと" do
      FactoryBot.create(:singing_diagnosis, customer: customer, status: :queued)
      expect(described_class.call(customer)).to eq []
    end

    it "他のcustomerの診断・チャレンジを参照しないこと" do
      other = FactoryBot.create(:customer, domain_name: "singing")
      FactoryBot.create(:singing_diagnosis, :completed, customer: other, overall_score: 99)
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: other, target_key: "rhythm",
        completed: true, completed_at: 1.week.ago
      )
      expect(described_class.call(customer)).to be_empty
    end

    it "最大15件を返すこと" do
      20.times do |i|
        FactoryBot.create(
          :singing_diagnosis, :completed,
          customer: customer,
          overall_score: 50 + i,
          diagnosed_at: (20 - i).days.ago,
          created_at: (20 - i).days.ago
        )
      end
      expect(described_class.call(customer).size).to be <= 15
    end

    context "古い順(昇順)に返すこと" do
      it "occureed_atが昇順に並んでいること" do
        t1 = Time.zone.local(2026, 3, 1, 12, 0, 0)
        t2 = Time.zone.local(2026, 5, 1, 12, 0, 0)
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 60, diagnosed_at: t2, created_at: t2)
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 55, diagnosed_at: t1, created_at: t1)
        items = described_class.call(customer)
        expect(items.map(&:occurred_at)).to eq(items.map(&:occurred_at).sort)
      end
    end

    context "初回診断イベント" do
      before do
        FactoryBot.create(
          :singing_diagnosis, :completed,
          customer: customer, overall_score: 65,
          diagnosed_at: 1.month.ago, created_at: 1.month.ago
        )
      end

      it "first_diagnosis アイテムを生成すること" do
        first = described_class.call(customer).first
        expect(first.type).to eq :first_diagnosis
        expect(first.title).to eq "初回診断を開始"
        expect(first.highlight).to be true
      end

      it "スコアを body に含めること" do
        first = described_class.call(customer).first
        expect(first.body).to include("65点")
      end
    end

    context "スコア突破イベント" do
      it "2回目以降で80点を超えたとき score_breakthrough アイテムを生成すること" do
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 55, diagnosed_at: 2.months.ago, created_at: 2.months.ago)
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 82, diagnosed_at: 1.month.ago, created_at: 1.month.ago)
        items = described_class.call(customer)
        breakthroughs = items.select { |i| i.type == :score_breakthrough }
        expect(breakthroughs.map(&:title)).to include("総合スコア80点突破")
        expect(breakthroughs.find { |i| i.title.include?("80点") }.highlight).to be true
      end

      it "初回診断でスコアが60点以上でも score_breakthrough は生成しないこと" do
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 65, diagnosed_at: 1.month.ago, created_at: 1.month.ago)
        items = described_class.call(customer)
        expect(items.none? { |i| i.type == :score_breakthrough }).to be true
      end
    end

    context "自己ベスト更新イベント" do
      it "スコアが更新されたとき personal_best アイテムを生成すること" do
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 60, diagnosed_at: 2.months.ago, created_at: 2.months.ago)
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 75, diagnosed_at: 1.month.ago, created_at: 1.month.ago)
        items = described_class.call(customer)
        pb = items.find { |i| i.type == :personal_best }
        expect(pb).not_to be_nil
        expect(pb.title).to eq "ボーカル自己ベスト更新"
        expect(pb.body).to eq "60点 → 75点"
      end

      it "スコアが下がったときは personal_best を生成しないこと" do
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 80, diagnosed_at: 2.months.ago, created_at: 2.months.ago)
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 70, diagnosed_at: 1.month.ago, created_at: 1.month.ago)
        items = described_class.call(customer)
        expect(items.none? { |i| i.type == :personal_best }).to be true
      end
    end

    context "チャレンジ達成イベント" do
      before do
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, diagnosed_at: 2.months.ago, created_at: 2.months.ago)
      end

      it "完了済みチャレンジで mission_success アイテムを生成すること" do
        FactoryBot.create(
          :singing_ai_challenge_progress,
          customer: customer, target_key: "rhythm",
          completed: true, completed_at: 3.weeks.ago
        )
        items = described_class.call(customer)
        ms = items.find { |i| i.type == :mission_success }
        expect(ms).not_to be_nil
        expect(ms.title).to eq "リズムチャレンジ成功"
        expect(ms.highlight).to be true
      end

      it "未完了チャレンジは mission_success を生成しないこと" do
        FactoryBot.create(:singing_ai_challenge_progress, customer: customer, target_key: "pitch", completed: false)
        items = described_class.call(customer)
        expect(items.none? { |i| i.type == :mission_success }).to be true
      end
    end

    context "連続診断イベント" do
      it "3日連続診断で streak アイテムを生成すること" do
        base = Time.zone.local(2026, 5, 10, 12, 0, 0)
        3.times do |i|
          FactoryBot.create(
            :singing_diagnosis, :completed,
            customer: customer,
            diagnosed_at: base + i.days,
            created_at: base + i.days
          )
        end
        items = described_class.call(customer)
        streak = items.find { |i| i.type == :streak }
        expect(streak).not_to be_nil
        expect(streak.title).to eq "3日連続診断達成"
      end

      it "5日連続では highlight が true になること" do
        base = Time.zone.local(2026, 5, 1, 12, 0, 0)
        5.times do |i|
          FactoryBot.create(
            :singing_diagnosis, :completed,
            customer: customer,
            diagnosed_at: base + i.days,
            created_at: base + i.days
          )
        end
        items = described_class.call(customer)
        five_streak = items.find { |i| i.type == :streak && i.title.include?("5日") }
        expect(five_streak).not_to be_nil
        expect(five_streak.highlight).to be true
      end

      it "連続していない診断では streak を生成しないこと" do
        base = Time.zone.local(2026, 5, 1, 12, 0, 0)
        [0, 3, 7].each do |days_offset|
          FactoryBot.create(
            :singing_diagnosis, :completed,
            customer: customer,
            diagnosed_at: base + days_offset.days,
            created_at: base + days_offset.days
          )
        end
        items = described_class.call(customer)
        expect(items.none? { |i| i.type == :streak }).to be true
      end
    end

    context "Premiumフラグ" do
      before do
        FactoryBot.create(
          :singing_diagnosis, :completed,
          customer: customer,
          ai_comment: "すばらしい音程の安定感があります。",
          ai_comment_status: :ai_comment_completed,
          diagnosed_at: 1.month.ago,
          created_at: 1.month.ago
        )
      end

      it "premium: false のときAIコメントアイテムが含まれないこと" do
        items = described_class.call(customer, premium: false)
        expect(items.none? { |i| i.type == :ai_comment }).to be true
      end

      it "premium: true のときAIコメントアイテムが含まれること" do
        items = described_class.call(customer, premium: true)
        expect(items.any? { |i| i.type == :ai_comment }).to be true
        ai = items.find { |i| i.type == :ai_comment }
        expect(ai.premium_detail).to include("すばらしい")
      end

      it "mission_success の premium_detail は premium: true のときだけ含まれること" do
        FactoryBot.create(
          :singing_ai_challenge_progress,
          customer: customer, target_key: "expression",
          completed: true, completed_at: 3.weeks.ago
        )
        items_free    = described_class.call(customer, premium: false)
        items_premium = described_class.call(customer, premium: true)
        free_ms    = items_free.find { |i| i.type == :mission_success }
        premium_ms = items_premium.find { |i| i.type == :mission_success }
        expect(free_ms.premium_detail).to be_nil
        expect(premium_ms.premium_detail).to be_present
      end
    end

    context "nil安全性" do
      it "スコアがnilの診断でも例外を発生させないこと" do
        diag = FactoryBot.create(:singing_diagnosis, :completed, customer: customer)
        diag.update_columns(overall_score: nil, pitch_score: nil, rhythm_score: nil, expression_score: nil, diagnosed_at: nil)
        expect { described_class.call(customer) }.not_to raise_error
      end

      it "completed_atがnilのチャレンジでも例外を発生させないこと" do
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, diagnosed_at: 1.month.ago, created_at: 1.month.ago)
        FactoryBot.create(
          :singing_ai_challenge_progress,
          customer: customer, target_key: "pitch",
          completed: true, completed_at: nil
        )
        expect { described_class.call(customer) }.not_to raise_error
      end
    end
  end
end
