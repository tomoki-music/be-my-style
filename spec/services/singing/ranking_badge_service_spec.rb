require 'rails_helper'

RSpec.describe Singing::RankingBadgeService, type: :service do
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  def create_singing_customer
    customer = FactoryBot.create(:customer, domain_name: "singing")
    CustomerDomain.find_or_create_by!(customer: customer, domain: singing_domain)
    customer
  end

  def badge_keys(customer)
    described_class.badges_for(customer).map { |badge| badge[:key] }
  end

  describe ".badges_for" do
    it "配列を返すこと" do
      customer = create_singing_customer

      expect(described_class.badges_for(customer)).to be_a(Array)
    end

    it "初診断バッジを付与すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 70)

      expect(badge_keys(customer)).to include(:first_diagnosis)
    end

    it "3回診断達成バッジを付与すること" do
      customer = create_singing_customer
      FactoryBot.create_list(:singing_diagnosis, 3, :completed, customer: customer)

      expect(badge_keys(customer)).to include(:diagnoses_3)
    end

    it "10回診断達成バッジを付与すること" do
      customer = create_singing_customer
      FactoryBot.create_list(:singing_diagnosis, 10, :completed, customer: customer)

      expect(badge_keys(customer)).to include(:diagnoses_10)
    end

    it "30回診断達成バッジを付与すること" do
      customer = create_singing_customer
      FactoryBot.create_list(:singing_diagnosis, 30, :completed, customer: customer)

      expect(badge_keys(customer)).to include(:diagnoses_30)
    end

    it "成長したユーザーに初成長バッジを付与すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 60, created_at: 2.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 65, created_at: 1.day.ago)

      expect(badge_keys(customer)).to include(:first_growth)
    end

    it "成長幅 +10突破バッジを付与すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 60, created_at: 2.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 75, created_at: 1.day.ago)

      expect(badge_keys(customer)).to include(:growth_plus_10)
    end

    it "成長ランキングTOP3バッジを付与すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
                        overall_score: 60, ranking_opt_in: false, created_at: 2.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: customer,
                        overall_score: 80, created_at: 1.day.ago)

      expect(badge_keys(customer)).to include(:growth_top_3)
    end

    it "今月ランクイン / TOP10 / 1位バッジを付与すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 90, diagnosed_at: Time.zone.now)

      expect(badge_keys(customer)).to include(:season_ranked, :season_top_10, :season_top_1)
    end

    it "総合TOP10 / TOP3バッジを付与すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 90)

      expect(badge_keys(customer)).to include(:overall_top_10, :overall_top_3)
    end

    it "rarity と将来拡張用フラグを含むこと" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 70)

      badge = described_class.badges_for(customer).first
      expect(badge).to include(
        rarity: :common,
        premium_only: false,
        animated: false
      )
    end

    it "強い称号を優先して返すこと" do
      customer = create_singing_customer
      FactoryBot.create_list(:singing_diagnosis, 29, :completed, customer: customer, overall_score: 70)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 95, diagnosed_at: Time.zone.now)

      expect(badge_keys(customer).first(4)).to eq([:season_top_1, :overall_top_3, :growth_top_3, :diagnoses_30])
    end
  end

  describe ".badges_for_bulk" do
    it "customer_id => badges のHashを返すこと" do
      customer = create_singing_customer
      other_customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer, overall_score: 70)
      FactoryBot.create(:singing_diagnosis, :completed, customer: other_customer, overall_score: 80)

      result = described_class.badges_for_bulk([customer, other_customer])

      expect(result.keys).to contain_exactly(customer.id, other_customer.id)
      expect(result[customer.id]).to all(include(:key, :label, :icon, :rarity))
    end
  end
end
