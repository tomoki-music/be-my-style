require "rails_helper"

RSpec.describe Singing::CommunityFeedBuilder do
  def make_diagnosis(customer:, score: 70, created_at: Time.current)
    create(:singing_diagnosis, :completed,
           customer:       customer,
           overall_score:  score,
           pitch_score:    score,
           rhythm_score:   score,
           expression_score: score,
           created_at:     created_at)
  end

  describe ".call" do
    subject(:result) { described_class.call }

    context "診断が存在しない場合" do
      it "空の feed を返す" do
        expect(result.feed_items).to be_empty
      end

      it "CommunityFeed オブジェクトを返す" do
        expect(result).to be_a(Singing::CommunityFeedBuilder::CommunityFeed)
      end
    end

    context "診断完了イベント" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Tomoki") }
      let!(:diagnosis) { make_diagnosis(customer: customer, created_at: 3.days.ago) }

      it ":diagnosis_completed の FeedItem が含まれる" do
        item = result.feed_items.find { |i| i.type == :diagnosis_completed && i.customer == customer }
        expect(item).to be_present
      end

      it "icon が 🎤 である" do
        item = result.feed_items.find { |i| i.type == :diagnosis_completed && i.customer == customer }
        expect(item.icon).to eq("🎤")
      end

      it "message が「新しい診断に挑戦しました」である" do
        item = result.feed_items.find { |i| i.type == :diagnosis_completed && i.customer == customer }
        expect(item.message).to eq("新しい診断に挑戦しました")
      end

      it "message にスコアが含まれない" do
        item = result.feed_items.find { |i| i.type == :diagnosis_completed && i.customer == customer }
        expect(item.message).not_to match(/\d+点/)
      end
    end

    context "自己ベスト更新イベント" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Yuki") }

      before do
        make_diagnosis(customer: customer, score: 70, created_at: 20.days.ago)
        make_diagnosis(customer: customer, score: 85, created_at: 5.days.ago)
      end

      it ":personal_best の FeedItem が含まれる" do
        item = result.feed_items.find { |i| i.type == :personal_best && i.customer == customer }
        expect(item).to be_present
      end

      it "icon が ⭐ である" do
        item = result.feed_items.find { |i| i.type == :personal_best && i.customer == customer }
        expect(item.icon).to eq("⭐")
      end

      it "message が「自己ベスト更新」である" do
        item = result.feed_items.find { |i| i.type == :personal_best && i.customer == customer }
        expect(item.message).to eq("自己ベスト更新")
      end

      it "message にスコアが含まれない（スコア表示禁止）" do
        item = result.feed_items.find { |i| i.type == :personal_best && i.customer == customer }
        expect(item.message).not_to include("85")
        expect(item.message).not_to match(/\d+点/)
      end
    end

    context "前回より低いスコアの場合" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Miki") }

      before do
        make_diagnosis(customer: customer, score: 85, created_at: 20.days.ago)
        make_diagnosis(customer: customer, score: 70, created_at: 5.days.ago)
      end

      it ":personal_best の FeedItem が含まれない" do
        items = result.feed_items.select { |i| i.type == :personal_best && i.customer == customer }
        expect(items).to be_empty
      end
    end

    context "自己ベストが lookback 外の古い診断との比較" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Sato") }

      before do
        make_diagnosis(customer: customer, score: 60, created_at: 60.days.ago)
        make_diagnosis(customer: customer, score: 80, created_at: 5.days.ago)
      end

      it "古い診断を超えた場合も :personal_best が生成される" do
        item = result.feed_items.find { |i| i.type == :personal_best && i.customer == customer }
        expect(item).to be_present
      end
    end

    context "7日継続達成イベント" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Riko") }

      before do
        7.times { |i| make_diagnosis(customer: customer, created_at: (8 - i).days.ago) }
      end

      it ":streak_milestone の FeedItem が含まれる" do
        item = result.feed_items.find { |i| i.type == :streak_milestone && i.customer == customer }
        expect(item).to be_present
      end

      it "icon が 🔥 である" do
        item = result.feed_items.find { |i| i.type == :streak_milestone && i.customer == customer }
        expect(item.icon).to eq("🔥")
      end

      it "message が「7日継続達成」である" do
        item = result.feed_items.find { |i| i.type == :streak_milestone && i.customer == customer }
        expect(item.message).to eq("7日継続達成")
      end
    end

    context "6日継続の場合（7日未達）" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Hana") }

      before do
        6.times { |i| make_diagnosis(customer: customer, created_at: (7 - i).days.ago) }
      end

      it ":streak_milestone の FeedItem が含まれない" do
        items = result.feed_items.select { |i| i.type == :streak_milestone && i.customer == customer }
        expect(items).to be_empty
      end
    end

    context "7日連続だが途中にギャップがある場合" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Nao") }

      before do
        # 3日連続、ギャップ、3日連続（合計6日だが連続ではない）
        3.times { |i| make_diagnosis(customer: customer, created_at: (14 - i).days.ago) }
        3.times { |i| make_diagnosis(customer: customer, created_at: (8 - i).days.ago) }
      end

      it ":streak_milestone の FeedItem が含まれない" do
        items = result.feed_items.select { |i| i.type == :streak_milestone && i.customer == customer }
        expect(items).to be_empty
      end
    end

    context "Challenge達成イベント" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Kana") }
      let!(:challenge_progress) do
        create(:singing_ai_challenge_progress,
               customer:     customer,
               completed:    true,
               completed_at: 2.days.ago)
      end

      it ":challenge_achieved の FeedItem が含まれる" do
        item = result.feed_items.find { |i| i.type == :challenge_achieved && i.customer == customer }
        expect(item).to be_present
      end

      it "icon が 🏆 である" do
        item = result.feed_items.find { |i| i.type == :challenge_achieved && i.customer == customer }
        expect(item.icon).to eq("🏆")
      end

      it "message が「Challenge達成」である" do
        item = result.feed_items.find { |i| i.type == :challenge_achieved && i.customer == customer }
        expect(item.message).to eq("Challenge達成")
      end
    end

    context "completed が false の Challenge" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Incomplete") }
      let!(:incomplete_challenge) do
        create(:singing_ai_challenge_progress,
               customer:  customer,
               completed: false)
      end

      it ":challenge_achieved の FeedItem が含まれない" do
        items = result.feed_items.select { |i| i.type == :challenge_achieved && i.customer == customer }
        expect(items).to be_empty
      end
    end

    context "ソート順" do
      let!(:customer_a) { create(:customer, domain_name: "singing", name: "A") }
      let!(:customer_b) { create(:customer, domain_name: "singing", name: "B") }
      let!(:customer_c) { create(:customer, domain_name: "singing", name: "C") }

      before do
        make_diagnosis(customer: customer_a, created_at: 10.days.ago)
        make_diagnosis(customer: customer_b, created_at: 5.days.ago)
        make_diagnosis(customer: customer_c, created_at: 1.day.ago)
      end

      it "occurred_at の降順（新しい順）で返す" do
        times = result.feed_items.map(&:occurred_at)
        expect(times).to eq(times.sort.reverse)
      end
    end

    context "最大10件制限" do
      before do
        12.times do |i|
          customer = create(:customer, domain_name: "singing")
          make_diagnosis(customer: customer, created_at: (i + 1).days.ago)
        end
      end

      it "feed_items が10件以下になる" do
        expect(result.feed_items.size).to be <= Singing::CommunityFeedBuilder::FEED_LIMIT
      end
    end

    context "lookback 外の古い診断のみの場合" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Old") }

      before do
        make_diagnosis(customer: customer, created_at: 40.days.ago)
      end

      it "feed が空になる" do
        expect(result.feed_items).to be_empty
      end
    end

    context "FeedItem の構造確認" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Struct") }

      before { make_diagnosis(customer: customer, created_at: 1.day.ago) }

      it "FeedItem が type / customer / message / icon / occurred_at を持つ" do
        item = result.feed_items.first
        expect(item.type).to be_a(Symbol)
        expect(item.customer).to be_present
        expect(item.message).to be_a(String)
        expect(item.icon).to be_a(String)
        expect(item.occurred_at).to be_present
      end

      it "FeedItem の customer が Customer インスタンスである" do
        item = result.feed_items.first
        expect(item.customer).to be_a(Customer)
      end
    end

    context "name が空白の customer でも item が作れる" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Placeholder") }

      before do
        customer.update_column(:name, "")
        make_diagnosis(customer: customer, created_at: 1.day.ago)
      end

      it "feed_items が生成される（エラーにならない）" do
        expect { result }.not_to raise_error
      end

      it "blank name の customer の item が含まれる" do
        item = result.feed_items.find { |i| i.customer == customer }
        expect(item).to be_present
      end
    end
  end
end
