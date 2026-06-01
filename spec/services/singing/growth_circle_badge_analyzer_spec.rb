require "rails_helper"

RSpec.describe Singing::GrowthCircleBadgeAnalyzer do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:other1)   { create(:customer, domain_name: "singing") }
  let(:other2)   { create(:customer, domain_name: "singing") }
  let(:other3)   { create(:customer, domain_name: "singing") }

  describe ".call" do
    context "customer が nil のとき" do
      it "空配列を返す" do
        expect(described_class.call(nil)).to eq([])
      end
    end

    context "行動データが何もないとき" do
      it "空配列を返す" do
        expect(described_class.call(customer)).to eq([])
      end
    end

    context "Community Supporter: 応援送信が閾値以上のとき" do
      before do
        # customer が 3 人に応援を送る
        create(:singing_cheer_reaction, customer: customer, target_customer: other1, reaction_type: "fire")
        create(:singing_cheer_reaction, customer: customer, target_customer: other2, reaction_type: "clap")
        create(:singing_cheer_reaction, customer: customer, target_customer: other3, reaction_type: "sing")
      end

      it "community_supporter バッジを返す" do
        badges = described_class.call(customer)
        expect(badges.map(&:key)).to include(:community_supporter)
      end
    end

    context "Growth Inspirer: 応援受信が閾値以上のとき" do
      before do
        # customer が 3 人から応援を受ける
        create(:singing_cheer_reaction, customer: other1, target_customer: customer, reaction_type: "fire")
        create(:singing_cheer_reaction, customer: other2, target_customer: customer, reaction_type: "clap")
        create(:singing_cheer_reaction, customer: other3, target_customer: customer, reaction_type: "sing")
      end

      it "growth_inspirer バッジを返す" do
        badges = described_class.call(customer)
        expect(badges.map(&:key)).to include(:growth_inspirer)
      end
    end

    context "Motivation Booster: 異なる 3 人以上に応援したとき" do
      before do
        create(:singing_cheer_reaction, customer: customer, target_customer: other1, reaction_type: "fire")
        create(:singing_cheer_reaction, customer: customer, target_customer: other2, reaction_type: "fire")
        create(:singing_cheer_reaction, customer: customer, target_customer: other3, reaction_type: "clap")
      end

      it "motivation_booster バッジを返す" do
        badges = described_class.call(customer)
        expect(badges.map(&:key)).to include(:motivation_booster)
      end
    end

    context "Consistency Champion: 継続日数が閾値以上のとき" do
      before do
        # 7 日分の診断を作成
        7.times do |i|
          create(:singing_diagnosis, :completed, customer: customer, created_at: i.days.ago)
        end
      end

      it "consistency_champion バッジを返す" do
        badges = described_class.call(customer)
        expect(badges.map(&:key)).to include(:consistency_champion)
      end
    end

    context "Rising Singer: 直近スコアが 3 点以上伸びたとき" do
      before do
        create(:singing_diagnosis, :completed, customer: customer, overall_score: 70, created_at: 5.days.ago)
        create(:singing_diagnosis, :completed, customer: customer, overall_score: 74, created_at: 1.day.ago)
      end

      it "rising_singer バッジを返す" do
        badges = described_class.call(customer)
        expect(badges.map(&:key)).to include(:rising_singer)
      end
    end

    context "閾値未満のとき" do
      before do
        # 応援を 2 回だけ（閾値 3 未満）
        create(:singing_cheer_reaction, customer: customer, target_customer: other1, reaction_type: "fire")
        create(:singing_cheer_reaction, customer: customer, target_customer: other2, reaction_type: "fire")
      end

      it "バッジを付与しない" do
        badges = described_class.call(customer)
        expect(badges.map(&:key)).not_to include(:community_supporter)
      end
    end

    context "複数のバッジが該当するとき" do
      before do
        # community_supporter 条件
        create(:singing_cheer_reaction, customer: customer, target_customer: other1, reaction_type: "fire")
        create(:singing_cheer_reaction, customer: customer, target_customer: other2, reaction_type: "clap")
        create(:singing_cheer_reaction, customer: customer, target_customer: other3, reaction_type: "sing")
        # growth_inspirer 条件
        create(:singing_cheer_reaction, customer: other1, target_customer: customer, reaction_type: "fire")
        create(:singing_cheer_reaction, customer: other2, target_customer: customer, reaction_type: "clap")
        create(:singing_cheer_reaction, customer: other3, target_customer: customer, reaction_type: "sing")
      end

      it "複数バッジを返す" do
        badges = described_class.call(customer)
        expect(badges.size).to be >= 2
      end

      it "先頭がプライマリバッジ（スコア最高）になる" do
        badges = described_class.call(customer)
        expect(badges.first).not_to be_nil
        expect(badges.first.key).to be_a(Symbol)
      end
    end

    describe "GrowthCircleBadge DTO" do
      before do
        3.times do |i|
          target = create(:customer, domain_name: "singing")
          create(:singing_cheer_reaction, customer: customer, target_customer: target, reaction_type: "fire")
        end
      end

      it "key, title, description, icon, color を持つ" do
        badge = described_class.call(customer).first
        expect(badge.key).to         be_a(Symbol)
        expect(badge.title).to       be_a(String)
        expect(badge.description).to be_a(String)
        expect(badge.icon).to        be_a(String)
        expect(badge.color).to       match(/\A#[0-9A-Fa-f]{6}\z/)
      end
    end
  end
end
