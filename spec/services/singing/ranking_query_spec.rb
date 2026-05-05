require 'rails_helper'

RSpec.describe Singing::RankingQuery, type: :service do
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  def create_singing_customer
    customer = FactoryBot.create(:customer, domain_name: "singing")
    CustomerDomain.find_or_create_by!(customer: customer, domain: singing_domain)
    customer
  end

  describe ".overall" do
    it "スコア降順で返すこと" do
      customer_a = create_singing_customer
      customer_b = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer_a, overall_score: 70)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer_b, overall_score: 90)

      result = described_class.overall
      expect(result.map(&:overall_score)).to eq([90, 70])
    end

    it "同一ユーザーの複数診断はベストスコアの1件のみ返すこと" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer, overall_score: 60)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer, overall_score: 85)

      result = described_class.overall
      expect(result.size).to eq(1)
      expect(result.first.overall_score).to eq(85)
    end

    it "ranking_opt_in=false の診断を除外すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 90, ranking_opt_in: false)

      expect(described_class.overall).to be_empty
    end

    it "overall_score が nil の診断を除外すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, overall_score: nil, ranking_opt_in: true)

      expect(described_class.overall).to be_empty
    end

    it "completed 以外のステータスを除外すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, customer: customer, status: :failed, overall_score: 80, ranking_opt_in: true)

      expect(described_class.overall).to be_empty
    end

    it "customer のアソシエーションをプリロードすること（N+1なし）" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer, overall_score: 80)

      result = described_class.overall
      expect(result.first.association(:customer)).to be_loaded
    end
  end

  describe ".position_for" do
    it "正しい順位を返すこと" do
      customer_a = create_singing_customer
      customer_b = create_singing_customer
      customer_c = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer_a, overall_score: 90)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer_b, overall_score: 80)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer_c, overall_score: 70)

      expect(described_class.position_for(customer_a.id)).to eq(1)
      expect(described_class.position_for(customer_b.id)).to eq(2)
      expect(described_class.position_for(customer_c.id)).to eq(3)
    end

    it "ランキング不参加のユーザーは nil を返すこと" do
      customer = create_singing_customer
      expect(described_class.position_for(customer.id)).to be_nil
    end

    it "nil を渡すと nil を返すこと" do
      expect(described_class.position_for(nil)).to be_nil
    end

    it "同一ユーザーの複数診断はベストスコアで順位を計算すること" do
      customer_a = create_singing_customer
      customer_b = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer_a, overall_score: 60)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer_a, overall_score: 85)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer_b, overall_score: 90)

      expect(described_class.position_for(customer_a.id)).to eq(2)
    end
  end
end
