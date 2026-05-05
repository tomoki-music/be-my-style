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

  describe ".growth" do
    it "成長幅の大きい順に返すこと" do
      customer_a = create_singing_customer
      customer_b = create_singing_customer

      FactoryBot.create(:singing_diagnosis, :completed, customer: customer_a,
                        overall_score: 60, ranking_opt_in: false, created_at: 2.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer_a, overall_score: 75, created_at: 1.day.ago)

      FactoryBot.create(:singing_diagnosis, :completed, customer: customer_b,
                        overall_score: 50, ranking_opt_in: false, created_at: 2.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer_b, overall_score: 80, created_at: 1.day.ago)

      result = described_class.growth
      expect(result.map(&:growth_score)).to eq([30, 15])
      expect(result.first.customer.id).to eq(customer_b.id)
    end

    it "スコアが前回より下がったユーザーは除外すること" do
      customer = create_singing_customer

      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
                        overall_score: 90, ranking_opt_in: false, created_at: 2.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 70, created_at: 1.day.ago)

      expect(described_class.growth).to be_empty
    end

    it "前回と同スコアのユーザーは除外すること" do
      customer = create_singing_customer

      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
                        overall_score: 75, ranking_opt_in: false, created_at: 2.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 75, created_at: 1.day.ago)

      expect(described_class.growth).to be_empty
    end

    it "診断が1件のみのユーザーは除外すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 80)

      expect(described_class.growth).to be_empty
    end

    it "ranking_opt_in=false の最新診断しか持たないユーザーは除外すること" do
      customer = create_singing_customer

      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
                        overall_score: 60, ranking_opt_in: false, created_at: 2.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
                        overall_score: 80, ranking_opt_in: false, created_at: 1.day.ago)

      expect(described_class.growth).to be_empty
    end

    it "GrowthEntry に customer / latest_diagnosis / previous_diagnosis / growth_score が含まれること" do
      customer = create_singing_customer

      prev_d = FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
                                 overall_score: 60, ranking_opt_in: false, created_at: 2.days.ago)
      latest_d = FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                                   customer: customer, overall_score: 80, created_at: 1.day.ago)

      result = described_class.growth
      expect(result.size).to eq(1)
      entry = result.first
      expect(entry.customer.id).to eq(customer.id)
      expect(entry.latest_diagnosis.id).to eq(latest_d.id)
      expect(entry.previous_diagnosis.id).to eq(prev_d.id)
      expect(entry.growth_score).to eq(20)
    end

    it "customer のアソシエーションをプリロードすること（N+1なし）" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
                        overall_score: 60, ranking_opt_in: false, created_at: 2.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 80, created_at: 1.day.ago)

      result = described_class.growth
      expect(result.first.customer.association(:profile_image_attachment)).to be_loaded
    end

    it "同成長幅の場合、最新診断日が新しい順に並ぶこと" do
      customer_a = create_singing_customer
      customer_b = create_singing_customer

      FactoryBot.create(:singing_diagnosis, :completed, customer: customer_a,
                        overall_score: 60, ranking_opt_in: false, created_at: 3.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer_a, overall_score: 80, created_at: 2.days.ago,
                        diagnosed_at: 2.days.ago)

      FactoryBot.create(:singing_diagnosis, :completed, customer: customer_b,
                        overall_score: 60, ranking_opt_in: false, created_at: 3.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer_b, overall_score: 80, created_at: 1.day.ago,
                        diagnosed_at: 1.day.ago)

      result = described_class.growth
      expect(result.first.customer.id).to eq(customer_b.id)
    end
  end

  describe ".current_season_range" do
    it "今月の開始〜翌月開始の範囲を返すこと" do
      range = described_class.current_season_range
      expect(range.begin).to eq(Time.zone.now.beginning_of_month)
      expect(range.end).to eq(Time.zone.now.next_month.beginning_of_month)
    end

    it "終端を含まない Range であること" do
      range = described_class.current_season_range
      expect(range).to be_a(Range)
      expect(range.exclude_end?).to be true
    end
  end

  describe ".season" do
    it "今月の診断のみ返すこと" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 80, diagnosed_at: Time.zone.now)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 90, diagnosed_at: 1.month.ago)

      result = described_class.season
      expect(result.size).to eq(1)
      expect(result.first.overall_score).to eq(80)
    end

    it "先月の診断は含まれないこと" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 90, diagnosed_at: 1.month.ago)

      expect(described_class.season).to be_empty
    end

    it "スコア降順で返すこと" do
      customer_a = create_singing_customer
      customer_b = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer_a, overall_score: 70, diagnosed_at: Time.zone.now)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer_b, overall_score: 90, diagnosed_at: Time.zone.now)

      result = described_class.season
      expect(result.map(&:overall_score)).to eq([90, 70])
    end

    it "同一ユーザーは今月の最高スコア1件のみ返すこと" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 60, diagnosed_at: 3.days.ago)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 85, diagnosed_at: 1.day.ago)

      result = described_class.season
      expect(result.size).to eq(1)
      expect(result.first.overall_score).to eq(85)
    end

    it "ranking_opt_in=false の診断を除外すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: customer,
                        overall_score: 90, ranking_opt_in: false, diagnosed_at: Time.zone.now)

      expect(described_class.season).to be_empty
    end

    it "diagnosed_at が nil の診断を除外すること" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 80, diagnosed_at: nil)

      expect(described_class.season).to be_empty
    end

    it "customer のアソシエーションをプリロードすること（N+1なし）" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 80, diagnosed_at: Time.zone.now)

      result = described_class.season
      expect(result.first.association(:customer)).to be_loaded
    end

    it "任意の期間を引数で指定できること" do
      customer = create_singing_customer
      last_month_range = 1.month.ago.beginning_of_month...1.month.ago.next_month.beginning_of_month
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 80, diagnosed_at: 1.month.ago)

      result = described_class.season(last_month_range)
      expect(result.size).to eq(1)
    end
  end

  describe ".season_position_for" do
    it "今月の正しい順位を返すこと" do
      customer_a = create_singing_customer
      customer_b = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer_a, overall_score: 90, diagnosed_at: Time.zone.now)
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer_b, overall_score: 70, diagnosed_at: Time.zone.now)

      expect(described_class.season_position_for(customer_a.id)).to eq(1)
      expect(described_class.season_position_for(customer_b.id)).to eq(2)
    end

    it "今月ランキング不参加のユーザーは nil を返すこと" do
      customer = create_singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant,
                        customer: customer, overall_score: 80, diagnosed_at: 1.month.ago)

      expect(described_class.season_position_for(customer.id)).to be_nil
    end

    it "nil を渡すと nil を返すこと" do
      expect(described_class.season_position_for(nil)).to be_nil
    end
  end
end
