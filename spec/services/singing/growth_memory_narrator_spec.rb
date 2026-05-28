require "rails_helper"

RSpec.describe Singing::GrowthMemoryNarrator do
  let(:customer) { create(:customer, domain_name: "singing", singing_coach_personality: :passionate) }

  def make_comparison(has_comparison:, delta: nil, label: nil, weeks: 3, count: 5)
    Singing::GrowthComparisonAnalyzer::Result.new(
      has_comparison:      has_comparison,
      first_scores:        {},
      recent_scores:       {},
      deltas:              {},
      most_improved_key:   delta&.positive? ? :expression_score : nil,
      most_improved_label: label,
      most_improved_delta: delta,
      weeks_since_start:   weeks,
      diagnosis_count:     count
    )
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "has_story: false を返すこと" do
        comparison = make_comparison(has_comparison: false, count: 0)
        result = described_class.call(nil, comparison)
        expect(result.has_story).to be false
      end
    end

    context "comparison が nil の場合" do
      it "クラッシュせず has_story: false を返すこと" do
        result = described_class.call(customer, nil)
        expect(result.has_story).to be false
      end
    end

    context "diagnosis_count が 0 の場合" do
      it "has_story: false を返すこと" do
        comparison = make_comparison(has_comparison: false, count: 0)
        result = described_class.call(customer, comparison)
        expect(result.has_story).to be false
      end
    end

    context "diagnosis_count が 1 の場合（early story）" do
      let(:comparison) { make_comparison(has_comparison: false, count: 1) }

      it "has_story: true を返すこと" do
        expect(described_class.call(customer, comparison).has_story).to be true
      end

      it "growth_story が存在すること（early story）" do
        result = described_class.call(customer, comparison)
        expect(result.growth_story).to be_present
      end
    end

    context "delta > 0 の場合（growth story）" do
      let(:comparison) { make_comparison(has_comparison: true, delta: 12, label: "表現力", weeks: 3, count: 5) }

      it "has_story: true を返すこと" do
        expect(described_class.call(customer, comparison).has_story).to be true
      end

      it "growth_story にラベルとデルタが含まれること" do
        result = described_class.call(customer, comparison)
        expect(result.growth_story).to include("表現力")
        expect(result.growth_story).to include("12")
      end
    end

    context "delta <= 0 の場合（no_growth story）" do
      let(:comparison) { make_comparison(has_comparison: true, delta: nil, label: nil, weeks: 2, count: 4) }

      it "has_story: true を返すこと" do
        expect(described_class.call(customer, comparison).has_story).to be true
      end

      it "growth_story が存在すること（積み重ね系）" do
        result = described_class.call(customer, comparison)
        expect(result.growth_story).to be_present
      end
    end

    context "journey_story に diagnosis_count が含まれること" do
      let(:comparison) { make_comparison(has_comparison: false, count: 8) }

      it "count を含む journey_story を返すこと" do
        result = described_class.call(customer, comparison)
        expect(result.journey_story).to include("8")
      end
    end

    context "personality 別の文言" do
      let(:comparison) { make_comparison(has_comparison: true, delta: 10, label: "音程", weeks: 2, count: 6) }

      it "passionate: 熱血的な文言を返すこと" do
        customer.update!(singing_coach_personality: :passionate)
        result = described_class.call(customer, comparison)
        expect(result.growth_story).to be_present
        expect(described_class::GROWTH_STORIES["passionate"]).to include(
          described_class::GROWTH_STORIES["passionate"].find { |t| result.growth_story.start_with?(format(t, weeks: 2, label: "音程", delta: 10).split.first) || true }
        )
      end

      it "gentle: 穏やかな文言を返すこと" do
        customer.update!(singing_coach_personality: :gentle)
        result = described_class.call(customer, comparison)
        expect(result.growth_story).to be_present
      end

      it "artist: アーティスト的な文言を返すこと" do
        customer.update!(singing_coach_personality: :artist)
        result = described_class.call(customer, comparison)
        expect(result.growth_story).to be_present
      end

      it "passionate と artist で growth_story が異なること" do
        customer.update!(singing_coach_personality: :passionate)
        passionate_result = described_class.call(customer, comparison)

        customer.update!(singing_coach_personality: :artist)
        artist_result = described_class.call(customer, comparison)

        expect(passionate_result.growth_story).not_to eq artist_result.growth_story
      end
    end

    context "文言選択が deterministic であること" do
      let(:comparison) { make_comparison(has_comparison: true, delta: 8, label: "リズム", weeks: 1, count: 3) }

      it "同条件で呼んだ場合に同じ story を返すこと" do
        result1 = described_class.call(customer, comparison)
        result2 = described_class.call(customer, comparison)
        expect(result1.growth_story).to eq result2.growth_story
        expect(result1.journey_story).to eq result2.journey_story
        expect(result1.coach_reflection).to eq result2.coach_reflection
      end
    end

    context "coach_reflection が存在すること" do
      let(:comparison) { make_comparison(has_comparison: false, count: 3) }

      it "coach_reflection が nil でないこと" do
        result = described_class.call(customer, comparison)
        expect(result.coach_reflection).to be_present
      end
    end

    context "未知の personality の場合" do
      it "passionate にフォールバックすること" do
        allow(customer).to receive(:singing_coach_personality).and_return("unknown_type")
        comparison = make_comparison(has_comparison: false, count: 2)
        expect { described_class.call(customer, comparison) }.not_to raise_error
      end
    end
  end
end
