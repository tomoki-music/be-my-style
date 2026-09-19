require "rails_helper"

RSpec.describe Singing::GrowthFeedBuilder do
  # i=0 が最古(days_ago_start 日前)、i が増えるほど新しく・スコアも高い
  def create_customer_with_diagnoses(count: 3, days_ago_start: 10)
    customer = create(:customer, domain_name: "singing")
    count.times do |i|
      ts = (days_ago_start - i).days.ago
      create(:singing_diagnosis, :completed, :ranking_participant,
             customer:         customer,
             overall_score:    65 + i,
             pitch_score:      60 + i,
             rhythm_score:     62 + i,
             expression_score: 58 + i,
             created_at:       ts,
             diagnosed_at:     ts)
    end
    customer
  end

  describe ".call" do
    context "最近 30 日以内に診断がないとき" do
      before do
        customer = create(:customer, domain_name: "singing")
        ts = 40.days.ago
        create(:singing_diagnosis, :completed,
               customer:         customer,
               overall_score:    70,
               pitch_score:      65,
               rhythm_score:     65,
               expression_score: 65,
               created_at:       ts,
               diagnosed_at:     ts)
      end

      it "空の配列を返す" do
        expect(described_class.call).to be_empty
      end
    end

    context "最近 30 日以内に診断が 2 件以上あるとき" do
      let!(:customer) { create_customer_with_diagnoses(count: 3) }

      it "FeedItem を返す" do
        result = described_class.call
        expect(result).not_to be_empty
        expect(result.first).to be_a(Singing::GrowthFeedBuilder::FeedItem)
      end

      it "FeedItem に必要なフィールドが揃っている" do
        item = described_class.call.first
        expect(item.customer).to be_a(Customer)
        expect(item.growth_type).to be_present
        expect(item.most_improved_label).to be_present
        expect(item.most_improved_delta).to be_present
        expect(item.streak_days).to be >= 0
        expect(item.reaction_count).to eq(0)
        expect(item.feed_type).to be_present
        expect(item.feed_icon).to be_present
        expect(item.feed_label).to be_present
        expect(item.headline).to be_present
        expect(item.milestones).to be_present
        expect(item.shared_at).to be_a(ActiveSupport::TimeWithZone)
      end
    end

    context "診断が 1 件だけの場合" do
      let!(:customer) do
        customer = create(:customer, domain_name: "singing")
        ts = 3.days.ago
        create(:singing_diagnosis, :completed, :ranking_participant,
               customer:         customer,
               overall_score:    70,
               pitch_score:      65,
               rhythm_score:     65,
               expression_score: 65,
               created_at:       ts,
               diagnosed_at:     ts)
        customer
      end

      it "初めての診断Milestoneとしてフィードに含める" do
        item = described_class.call.first

        expect(item.customer).to eq(customer)
        expect(item.feed_type).to eq(:milestone)
        expect(item.milestones.map(&:message)).to include("初めての診断を完了しました")
        expect(item.most_improved_label).to be_nil
      end
    end

    context "limit オプション" do
      before do
        3.times { create_customer_with_diagnoses }
      end

      it "指定件数を超えないこと" do
        result = described_class.call(limit: 2)
        expect(result.size).to be <= 2
      end
    end

    context "複数ユーザーがいるとき" do
      let!(:customer_a) { create_customer_with_diagnoses(count: 3, days_ago_start: 15) }
      let!(:customer_b) { create_customer_with_diagnoses(count: 3, days_ago_start: 10) }

      it "shared_at 降順で返る" do
        result = described_class.call
        times  = result.map(&:shared_at)
        expect(times).to eq(times.sort.reverse)
      end
    end

    context "応援があるとき" do
      let!(:customer) { create_customer_with_diagnoses(count: 3) }
      let!(:supporter) { create(:customer, domain_name: "singing") }

      before do
        create(:singing_cheer_reaction, customer: supporter, target_customer: customer, reaction_type: "fire")
      end

      it "reaction_countを返す" do
        item = described_class.call.first

        expect(item.reaction_count).to eq(1)
      end
    end

    context "公開同意(ranking_opt_in)によるフィルタ" do
      def diagnosis_for(customer, ranking_opt_in:, days_ago: 3, overall_score: 70)
        ts = days_ago.days.ago
        create(:singing_diagnosis, :completed,
               customer:         customer,
               ranking_opt_in:   ranking_opt_in,
               overall_score:    overall_score,
               pitch_score:      overall_score,
               rhythm_score:     overall_score,
               expression_score: overall_score,
               created_at:       ts,
               diagnosed_at:     ts)
      end

      it "ranking_opt_in=true の診断はフィードに含まれる" do
        customer = create(:customer, domain_name: "singing")
        diagnosis_for(customer, ranking_opt_in: true)

        result = described_class.call
        expect(result.map(&:customer)).to include(customer)
      end

      it "ranking_opt_in=false の診断はフィードに含まれない" do
        customer = create(:customer, domain_name: "singing")
        diagnosis_for(customer, ranking_opt_in: false)

        result = described_class.call
        expect(result.map(&:customer)).not_to include(customer)
      end

      it "ranking_opt_in が未指定(デフォルトfalse)の診断はフィードに含まれない" do
        customer = create(:customer, domain_name: "singing")
        ts = 3.days.ago
        create(:singing_diagnosis, :completed,
               customer:         customer,
               overall_score:    70,
               pitch_score:      70,
               rhythm_score:     70,
               expression_score: 70,
               created_at:       ts,
               diagnosed_at:     ts)

        result = described_class.call
        expect(result.map(&:customer)).not_to include(customer)
      end

      it "非公開診断しか持たないユーザーはフィードに表示されない" do
        customer = create(:customer, domain_name: "singing")
        3.times { |i| diagnosis_for(customer, ranking_opt_in: false, days_ago: 10 - i) }

        result = described_class.call
        expect(result.map(&:customer)).not_to include(customer)
      end

      it "公開・非公開の診断が混在する場合は公開診断だけが集計・表示に使われる" do
        customer = create(:customer, domain_name: "singing")
        diagnosis_for(customer, ranking_opt_in: false, days_ago: 20, overall_score: 40)
        diagnosis_for(customer, ranking_opt_in: true,  days_ago: 3,  overall_score: 90)

        item = described_class.call.find { |i| i.customer == customer }
        expect(item).to be_present
        # 非公開の40点は「自己ベスト」の比較対象に使われず、公開の90点のみが基準になる
        expect(item.milestones.map(&:message)).to include("初めての診断を完了しました")
      end
    end
  end
end
