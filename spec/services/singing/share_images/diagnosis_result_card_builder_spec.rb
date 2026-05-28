require "rails_helper"

RSpec.describe Singing::ShareImages::DiagnosisResultCardBuilder, type: :service do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }

  describe "previous なし（初回診断）" do
    let(:diagnosis) do
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
        overall_score: 70, pitch_score: 68, rhythm_score: 72, expression_score: 65)
    end

    it "カードが生成されること" do
      card = described_class.call(diagnosis)
      expect(card).not_to be_nil
    end

    it "overall_score が設定されること" do
      card = described_class.call(diagnosis)
      expect(card.overall_score).to eq(70)
    end

    it "previous がないので delta は nil であること" do
      card = described_class.call(diagnosis)
      expect(card.overall_delta).to be_nil
      expect(card.overall_delta_label).to be_nil
    end

    it "best_growth_label が nil であること" do
      card = described_class.call(diagnosis)
      expect(card.best_growth_label).to be_nil
    end

    it "has_previous が false であること" do
      card = described_class.call(diagnosis)
      expect(card.has_previous).to eq(false)
    end

    it "headline に「初回」が含まれること" do
      card = described_class.call(diagnosis)
      expect(card.headline).to include("初回")
    end

    it "x_share_text にスコアが含まれること" do
      card = described_class.call(diagnosis)
      expect(card.x_share_text).to include("70")
    end
  end

  describe "previous あり（成長あり）" do
    let!(:previous_diagnosis) do
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
        overall_score: 65, pitch_score: 60, rhythm_score: 68, expression_score: 60,
        created_at: 2.days.ago)
    end
    let(:diagnosis) do
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
        overall_score: 72, pitch_score: 64, rhythm_score: 70, expression_score: 68)
    end

    it "overall_delta がプラスで計算されること" do
      card = described_class.call(diagnosis)
      expect(card.overall_delta).to eq(7)
      expect(card.overall_delta_label).to eq("+7")
    end

    it "has_previous が true であること" do
      card = described_class.call(diagnosis)
      expect(card.has_previous).to eq(true)
    end

    it "もっとも伸びた項目が best_growth_label に入ること" do
      card = described_class.call(diagnosis)
      expect(card.best_growth_label).to be_present
      expect(card.best_growth_delta_label).to match(/\A\+\d+\z/)
    end

    it "表現力が最大の伸びであれば best_growth_label が「表現力」になること" do
      card = described_class.call(diagnosis)
      expect(card.best_growth_label).to eq("表現力")
      expect(card.best_growth_delta_label).to eq("+8")
    end

    it "x_share_text にデルタ情報が含まれること" do
      card = described_class.call(diagnosis)
      expect(card.x_share_text).to include("+7")
    end
  end

  describe "streak あり" do
    let!(:diagnosis_day1) do
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
        overall_score: 60, created_at: 2.days.ago)
    end
    let!(:diagnosis_day2) do
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
        overall_score: 64, created_at: 1.day.ago)
    end
    let(:diagnosis) do
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
        overall_score: 68)
    end

    it "streak_days が 3 であること" do
      card = described_class.call(diagnosis)
      expect(card.streak_days).to eq(3)
    end

    it "streak_label が設定されること" do
      card = described_class.call(diagnosis)
      expect(card.streak_label).to eq("3日連続診断中")
    end

    it "x_share_text に連続診断の記述が含まれること" do
      card = described_class.call(diagnosis)
      expect(card.x_share_text).to include("連続診断中")
    end
  end

  describe "nil / 未完了 診断" do
    it "nil を渡すと nil を返すこと" do
      expect(described_class.call(nil)).to be_nil
    end

    it "未完了診断を渡すと nil を返すこと" do
      pending_diag = FactoryBot.create(:singing_diagnosis, customer: customer)
      expect(described_class.call(pending_diag)).to be_nil
    end
  end
end
