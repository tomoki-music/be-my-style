require "rails_helper"

RSpec.describe Singing::EncouragementSummaryBuilder do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:cheerleader_a) { create(:customer, domain_name: "singing") }
  let(:cheerleader_b) { create(:customer, domain_name: "singing") }

  def cheer(from:, type:, days_ago: 1)
    create(:singing_cheer_reaction,
           customer:        from,
           target_customer: customer,
           reaction_type:   type,
           created_at:      days_ago.days.ago)
  end

  describe ".call" do
    context "customer が nil のとき" do
      it "has_summary: false を返す" do
        result = described_class.call(nil)
        expect(result.has_summary).to be false
      end
    end

    context "直近 7 日以内に応援がないとき" do
      before do
        create(:singing_cheer_reaction,
               customer:        cheerleader_a,
               target_customer: customer,
               reaction_type:   "fire",
               created_at:      10.days.ago)
      end

      it "has_summary: false を返す" do
        expect(described_class.call(customer).has_summary).to be false
      end
    end

    context "直近 7 日以内に応援があるとき" do
      before do
        cheer(from: cheerleader_a, type: "fire")
        cheer(from: cheerleader_a, type: "sparkle")
        cheer(from: cheerleader_b, type: "fire")
        cheer(from: cheerleader_b, type: "clap")
      end

      it "has_summary: true を返す" do
        expect(described_class.call(customer).has_summary).to be true
      end

      it "total_count が正しい" do
        expect(described_class.call(customer).total_count).to eq(4)
      end

      it "unique_cheerleaders が正しい" do
        expect(described_class.call(customer).unique_cheerleaders).to eq(2)
      end

      it "counts_by_type が正しい" do
        counts = described_class.call(customer).counts_by_type
        expect(counts["fire"]).to   eq(2)
        expect(counts["clap"]).to   eq(1)
        expect(counts["sparkle"]).to eq(1)
        expect(counts["sing"]).to   eq(0)
      end

      it "top_reaction_type が最多のタイプを返す" do
        expect(described_class.call(customer).top_reaction_type).to eq("fire")
      end

      it "summary_message が文字列を返す" do
        expect(described_class.call(customer).summary_message).to be_a(String)
        expect(described_class.call(customer).summary_message).to include("2人")
        expect(described_class.call(customer).summary_message).to include("4件")
      end
    end

    context "7 日を超えた応援は集計に含まれない" do
      before do
        cheer(from: cheerleader_a, type: "fire", days_ago: 3)
        cheer(from: cheerleader_b, type: "clap", days_ago: 9)
      end

      it "期間外の応援はカウントされない" do
        result = described_class.call(customer)
        expect(result.total_count).to eq(1)
      end
    end
  end
end
