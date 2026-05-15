require "rails_helper"

RSpec.describe Singing::ShareImages::MonthlyWrappedCardBuilder, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:reference_time) { Time.zone.local(2026, 5, 15, 12, 0, 0) }

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

  context "当月に診断がある場合" do
    before do
      create_diagnosis(80, Time.zone.local(2026, 5, 1, 10, 0, 0))
      create_diagnosis(88, Time.zone.local(2026, 5, 14, 10, 0, 0))
    end

    it "Card Struct を返すこと" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card).to be_a(Singing::ShareImages::MonthlyWrappedCardBuilder::Card)
    end

    it "基本フィールドが揃っていること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.year).to eq(2026)
      expect(card.month).to eq(5)
      expect(card.month_label).to eq("2026年5月")
      expect(card.diagnosis_count).to eq(2)
      expect(card.best_score).to eq(88)
      expect(card.badge_label).to eq("Monthly Wrapped")
    end

    it "x_share_text に月・回数が含まれること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.x_share_text).to include("2026年5月")
      expect(card.x_share_text).to include("2回")
    end

    it "best_score_label を整形すること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.best_score_label).to eq("最高スコア 88点")
    end

    it "headline が診断回数に応じて変わること" do
      card = described_class.call(customer, reference_time: reference_time)

      expect(card.headline).to eq("2回挑戦しました")
    end

    context "診断が5回以上の場合" do
      before do
        3.times { |i| create_diagnosis(70 + i, Time.zone.local(2026, 5, 20 + i, 10, 0, 0)) }
      end

      it "headline が 5回歌いました になること" do
        card = described_class.call(customer, reference_time: reference_time)

        expect(card.headline).to eq("5回歌いました")
      end
    end

    context "前月比スコア改善がある場合" do
      before do
        create_diagnosis(60, Time.zone.local(2026, 4, 10, 10, 0, 0))
      end

      it "score_improvement_label がプラス表記になること" do
        card = described_class.call(customer, reference_time: reference_time)

        expect(card.score_improvement).to be_positive
        expect(card.score_improvement_label).to include("+")
      end

      it "x_share_text にスコアアップが含まれること" do
        card = described_class.call(customer, reference_time: reference_time)

        expect(card.x_share_text).to include("スコアアップ")
      end
    end

    context "前月比スコアがマイナスの場合" do
      before do
        create_diagnosis(95, Time.zone.local(2026, 4, 10, 10, 0, 0))
      end

      it "score_improvement_label がマイナス表記になること" do
        card = described_class.call(customer, reference_time: reference_time)

        expect(card.score_improvement_label).to match(/-\d/)
      end
    end

    context "前月データなしの場合" do
      it "score_improvement_label が前月データなし になること" do
        card = described_class.call(customer, reference_time: reference_time)

        expect(card.score_improvement_label).to eq("前月データなし")
      end
    end
  end

  context "当月に診断がない場合" do
    before do
      create_diagnosis(75, Time.zone.local(2026, 4, 10, 10, 0, 0))
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

  context "year/month パラメータで過去月を指定できること" do
    before do
      create_diagnosis(77, Time.zone.local(2026, 3, 10, 10, 0, 0))
    end

    it "指定月の Card を返すこと" do
      march_time = Time.zone.local(2026, 3, 15, 12, 0, 0)
      card = described_class.call(customer, reference_time: march_time)

      expect(card.year).to eq(2026)
      expect(card.month).to eq(3)
      expect(card.best_score).to eq(77)
    end
  end
end
