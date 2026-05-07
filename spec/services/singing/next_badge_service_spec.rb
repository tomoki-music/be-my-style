require 'rails_helper'

RSpec.describe Singing::NextBadgeService, type: :service do
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  def create_singing_customer
    customer = FactoryBot.create(:customer, domain_name: "singing")
    CustomerDomain.find_or_create_by!(customer: customer, domain: singing_domain)
    customer
  end

  def hint_keys(customer)
    described_class.call(customer).map(&:key)
  end

  before do
    allow(Singing::RankingQuery).to receive(:position_for).and_return(nil)
    allow(Singing::RankingQuery).to receive(:season_position_for).and_return(nil)
  end

  describe ".call" do
    context "customer が nil のとき" do
      it "空配列を返すこと" do
        expect(described_class.call(nil)).to eq([])
      end
    end

    it "最大3件しか返さないこと" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 60, created_at: 2.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 65, created_at: 1.day.ago)
      allow(Singing::RankingQuery).to receive(:season_position_for).and_return(15)
      allow(Singing::RankingQuery).to receive(:position_for).and_return(20)

      expect(described_class.call(customer).size).to be <= 3
    end

    it "Hint 構造体を返すこと" do
      customer = create_singing_customer
      result = described_class.call(customer)

      expect(result).to all(be_a(Singing::NextBadgeService::Hint))
    end
  end

  describe "診断回数バッジ" do
    context "診断回数が 0 のとき" do
      it "diagnoses_3 のヒントを返すこと" do
        customer = create_singing_customer
        expect(hint_keys(customer)).to include(:diagnoses_3)
      end

      it "ヒントに残り回数が含まれること" do
        customer = create_singing_customer
        hint = described_class.call(customer).find { |h| h.key == :diagnoses_3 }
        expect(hint.description).to include("3回")
      end
    end

    context "診断回数が 2 のとき" do
      it "diagnoses_3 のヒントを返し残り 1 回と表示すること" do
        customer = create_singing_customer
        FactoryBot.create_list(:singing_diagnosis, 2, :completed, customer: customer, overall_score: 70)
        hint = described_class.call(customer).find { |h| h.key == :diagnoses_3 }
        expect(hint).to be_present
        expect(hint.description).to include("1回")
      end
    end

    context "診断回数が 3 のとき" do
      it "diagnoses_3 のヒントを返さず diagnoses_10 を返すこと" do
        customer = create_singing_customer
        FactoryBot.create_list(:singing_diagnosis, 3, :completed, customer: customer, overall_score: 70)
        keys = hint_keys(customer)
        expect(keys).not_to include(:diagnoses_3)
        expect(keys).to include(:diagnoses_10)
      end
    end

    context "診断回数が 10 のとき" do
      it "diagnoses_30 のヒントを返すこと" do
        customer = create_singing_customer
        FactoryBot.create_list(:singing_diagnosis, 10, :completed, customer: customer, overall_score: 70)
        expect(hint_keys(customer)).to include(:diagnoses_30)
      end
    end

    context "診断回数が 30 以上のとき" do
      it "診断回数バッジのヒントを返さないこと" do
        customer = create_singing_customer
        FactoryBot.create_list(:singing_diagnosis, 30, :completed, customer: customer, overall_score: 70)
        diagnosis_keys = %i[diagnoses_3 diagnoses_10 diagnoses_30]
        expect(hint_keys(customer) & diagnosis_keys).to be_empty
      end
    end
  end

  describe "成長バッジ" do
    context "成長スコアが 1〜9 のとき" do
      it "growth_plus_10 のヒントを返すこと" do
        customer = create_singing_customer
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 60, created_at: 2.days.ago)
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 65, created_at: 1.day.ago)
        expect(hint_keys(customer)).to include(:growth_plus_10)
      end

      it "残り点数を表示すること" do
        customer = create_singing_customer
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 60, created_at: 2.days.ago)
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 65, created_at: 1.day.ago)
        hint = described_class.call(customer).find { |h| h.key == :growth_plus_10 }
        expect(hint.description).to include("5点")
      end
    end

    context "成長スコアが 10 以上のとき" do
      it "growth_plus_10 のヒントを返さないこと" do
        customer = create_singing_customer
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 60, created_at: 2.days.ago)
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 71, created_at: 1.day.ago)
        expect(hint_keys(customer)).not_to include(:growth_plus_10)
      end
    end

    context "診断が 2 回以上あり成長スコアが 0 以下のとき" do
      it "first_growth のヒントを返すこと" do
        customer = create_singing_customer
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 70, created_at: 2.days.ago)
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 70, created_at: 1.day.ago)
        expect(hint_keys(customer)).to include(:first_growth)
      end
    end

    context "診断が 1 回以下で成長スコアが計算できないとき" do
      it "first_growth のヒントを返さないこと" do
        customer = create_singing_customer
        FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 70)
        expect(hint_keys(customer)).not_to include(:first_growth)
      end
    end
  end

  describe "シーズンランクバッジ" do
    context "シーズン順位が 11〜20 のとき" do
      it "season_top_10 のヒントを返すこと" do
        customer = create_singing_customer
        allow(Singing::RankingQuery).to receive(:season_position_for).and_return(12)
        expect(hint_keys(customer)).to include(:season_top_10)
      end

      it "残り順位を表示すること" do
        customer = create_singing_customer
        allow(Singing::RankingQuery).to receive(:season_position_for).and_return(13)
        hint = described_class.call(customer).find { |h| h.key == :season_top_10 }
        expect(hint.description).to include("3順位")
      end
    end

    context "シーズン順位が 2〜5 のとき" do
      it "season_top_1 のヒントを返すこと" do
        customer = create_singing_customer
        allow(Singing::RankingQuery).to receive(:season_position_for).and_return(3)
        expect(hint_keys(customer)).to include(:season_top_1)
      end
    end

    context "シーズン順位が nil のとき" do
      it "シーズンランク関連ヒントを返さないこと" do
        customer = create_singing_customer
        keys = hint_keys(customer)
        expect(keys).not_to include(:season_top_10, :season_top_1)
      end
    end
  end

  describe "総合ランクバッジ" do
    context "総合順位が 11〜25 のとき" do
      it "overall_top_10 のヒントを返すこと" do
        customer = create_singing_customer
        allow(Singing::RankingQuery).to receive(:position_for).and_return(15)
        expect(hint_keys(customer)).to include(:overall_top_10)
      end
    end

    context "総合順位が 4〜8 のとき" do
      it "overall_top_3 のヒントを返すこと" do
        customer = create_singing_customer
        allow(Singing::RankingQuery).to receive(:position_for).and_return(5)
        expect(hint_keys(customer)).to include(:overall_top_3)
      end
    end

    context "総合順位が nil のとき" do
      it "総合ランク関連ヒントを返さないこと" do
        customer = create_singing_customer
        keys = hint_keys(customer)
        expect(keys).not_to include(:overall_top_10, :overall_top_3)
      end
    end
  end

  describe "proximity_score による優先順位" do
    it "達成に近いバッジを先に返すこと（season_top_10 rank=11 は近い）" do
      customer = create_singing_customer
      FactoryBot.create_list(:singing_diagnosis, 2, :completed, customer: customer, overall_score: 70)
      allow(Singing::RankingQuery).to receive(:season_position_for).and_return(11)

      hints = described_class.call(customer)
      expect(hints.first.key).to eq(:season_top_10)
    end
  end
end
