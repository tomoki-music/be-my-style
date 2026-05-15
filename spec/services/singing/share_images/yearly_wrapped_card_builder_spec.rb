require "rails_helper"

RSpec.describe Singing::ShareImages::YearlyWrappedCardBuilder, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:reference_time) { Time.zone.local(2026, 6, 15, 12, 0, 0) }

  around do |example|
    travel_to(reference_time) { example.run }
  end

  def create_diagnosis(score, created_at, **attrs)
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
      create_diagnosis(70, Time.zone.local(2026, 1, 10, 10, 0, 0), pitch_score: 62, rhythm_score: 65, expression_score: 58)
      create_diagnosis(88, Time.zone.local(2026, 6, 10, 10, 0, 0), pitch_score: 82, rhythm_score: 78, expression_score: 74)
    end

    it "Card Struct を返すこと" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card).to be_a(described_class::Card)
    end

    it "基本フィールドが揃っていること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.year).to eq(2026)
      expect(card.year_label).to eq("2026年")
      expect(card.diagnosis_count).to eq(2)
      expect(card.best_score).to eq(88)
      expect(card.badge_label).to eq("Yearly Wrapped")
    end

    it "best_score_label を整形すること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.best_score_label).to eq("最高スコア 88点")
    end

    it "score_growth_label がプラス表記になること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.score_growth).to eq(18)
      expect(card.score_growth_label).to eq("+18点")
    end

    it "top_skill_delta_label が nil でないこと" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.top_skill_delta_label).to be_present
    end

    it "headline にスキル名が含まれること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.headline).to be_present
    end

    it "x_share_text に年と診断回数が含まれること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.x_share_text).to include("2026年")
      expect(card.x_share_text).to include("2回")
    end
  end

  context "診断が1回のみ（成長比較不可）" do
    before do
      create_diagnosis(75, Time.zone.local(2026, 3, 10, 10, 0, 0))
    end

    it "score_growth_label が 初年度 になること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.score_growth_label).to eq("初年度")
    end

    it "top_skill_delta_label が nil になること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.top_skill_delta_label).to be_nil
    end
  end

  context "スコアが下降している場合" do
    before do
      create_diagnosis(90, Time.zone.local(2026, 1, 10, 10, 0, 0))
      create_diagnosis(78, Time.zone.local(2026, 6, 10, 10, 0, 0))
    end

    it "score_growth_label がマイナス表記になること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.score_growth_label).to match(/-\d/)
    end
  end

  context "top_month が複数あり最多月が確定できる場合" do
    before do
      create_diagnosis(75, Time.zone.local(2026, 3, 10, 10, 0, 0))
      create_diagnosis(78, Time.zone.local(2026, 3, 20, 10, 0, 0))
      create_diagnosis(80, Time.zone.local(2026, 6, 10, 10, 0, 0))
    end

    it "top_month_label に月名が含まれること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.top_month).to eq(3)
      expect(card.top_month_label).to include("3月")
    end
  end

  context "当年に診断がない場合" do
    before do
      create_diagnosis(75, Time.zone.local(2025, 12, 10, 10, 0, 0))
    end

    it "nil を返すこと" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card).to be_nil
    end
  end

  context "customer が nil の場合" do
    it "nil を返すこと" do
      expect(described_class.call(nil, reference_time: reference_time)).to be_nil
    end
  end
end
