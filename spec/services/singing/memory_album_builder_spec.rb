require "rails_helper"

RSpec.describe Singing::MemoryAlbumBuilder do
  let(:customer) { create(:customer, domain_name: "singing", singing_coach_personality: :passionate) }

  def diagnosis_at(year, month, day, overall: 70, pitch: 65, rhythm: 70, expression: 65)
    ts = Time.zone.local(year, month, day)
    create(:singing_diagnosis, :completed,
           customer:         customer,
           overall_score:    overall,
           pitch_score:      pitch,
           rhythm_score:     rhythm,
           expression_score: expression,
           created_at:       ts,
           diagnosed_at:     ts)
  end

  def call(cust = customer)
    described_class.call(cust)
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "空の AlbumResult を返す" do
        result = described_class.call(nil)
        expect(result.items).to be_empty
      end
    end

    context "診断が 0 件の場合" do
      it "items が空であること" do
        expect(call.items).to be_empty
      end
    end

    context "診断が 1 件以上ある場合" do
      before { diagnosis_at(2026, 1, 10) }

      it "AlbumResult を返すこと" do
        expect(call).to be_a(described_class::AlbumResult)
      end

      it "items に AlbumItem が含まれること" do
        expect(call.items).not_to be_empty
        expect(call.items.first).to be_a(described_class::AlbumItem)
      end

      it "items が新しい順に並んでいること" do
        diagnosis_at(2025, 6, 1)
        items = call.items
        dates = items.map(&:occurred_at)
        expect(dates).to eq(dates.sort.reverse)
      end
    end

    context "複数の月に診断がある場合" do
      before do
        diagnosis_at(2026, 1, 10)
        diagnosis_at(2026, 2, 15)
        diagnosis_at(2026, 3, 20)
      end

      it "monthly_wrapped アイテムが含まれること" do
        types = call.items.map(&:type)
        expect(types).to include(:monthly_wrapped)
      end

      it "AlbumItem の required フィールドが存在すること" do
        item = call.items.find { |i| i.type == :monthly_wrapped }
        expect(item.occurred_at).to be_a(Date)
        expect(item.title).to be_present
        expect(item.badge).to be_present
      end
    end

    context "年をまたいで診断がある場合" do
      before do
        diagnosis_at(2025, 6, 1)
        diagnosis_at(2026, 1, 10)
      end

      it "year_recap アイテムが含まれること" do
        types = call.items.map(&:type)
        expect(types).to include(:year_recap)
      end

      it "year_recap アイテムの occurred_at が年末であること" do
        item = call.items.find { |i| i.type == :year_recap }
        expect(item.occurred_at.month).to eq 12
        expect(item.occurred_at.day).to eq 31
      end
    end

    context "MAX_MONTHS を超える月数のデータがある場合" do
      it "monthly_wrapped アイテムが MAX_MONTHS 件を超えないこと" do
        stub_months = Array.new(30) { |i| [2024 - i / 12, 12 - (i % 12)] }
        allow_any_instance_of(described_class).to receive(:months_with_data).and_return(stub_months)
        allow_any_instance_of(described_class).to receive(:years_with_data).and_return([])
        allow(Singing::JourneyRecapBuilder).to receive(:call).and_return(
          double(has_story: false)
        )
        allow(Singing::MonthlyWrappedBuilder).to receive(:call).and_return(
          double(has_wrapped: false)
        )

        result = described_class.call(customer)
        monthly_items = result.items.select { |i| i.type == :monthly_wrapped }
        expect(monthly_items.size).to be <= described_class::MAX_MONTHS
      end
    end
  end

  describe "AlbumItem struct" do
    it "必要なフィールドを持つこと" do
      item = described_class::AlbumItem.new(
        type:        :monthly_wrapped,
        occurred_at: Date.new(2026, 1, 1),
        title:       "テスト",
        subtitle:    "サブ",
        summary:     "まとめ",
        badge:       "🎤",
        detail_url:  "/path"
      )
      expect(item.type).to eq :monthly_wrapped
      expect(item.occurred_at).to eq Date.new(2026, 1, 1)
    end
  end
end
