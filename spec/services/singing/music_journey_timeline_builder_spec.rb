require "rails_helper"

RSpec.describe Singing::MusicJourneyTimelineBuilder do
  let(:customer) { create(:customer, domain_name: "singing", name: "テストユーザー") }

  def make_diagnosis(score:, created_at:)
    create(:singing_diagnosis, :completed,
           customer: customer,
           overall_score: score,
           pitch_score: [score - 5, 0].max,
           rhythm_score: score,
           expression_score: [score - 3, 0].max,
           created_at: created_at)
  end

  describe ".call" do
    subject(:result) { described_class.call(customer) }

    context "nil customer の場合" do
      it "空の timeline を返す" do
        expect(described_class.call(nil).timeline_items).to eq([])
      end
    end

    context "診断がない場合" do
      it "空の timeline を返す" do
        expect(result.timeline_items).to eq([])
      end
    end

    context "初診断がある場合" do
      before { make_diagnosis(score: 65, created_at: 10.days.ago) }

      it "MusicJourneyTimeline を返す" do
        expect(result).to be_a(described_class::MusicJourneyTimeline)
      end

      it "timeline_items が Array である" do
        expect(result.timeline_items).to be_an(Array)
      end

      it "初診断イベントが含まれる" do
        expect(result.timeline_items.map(&:type)).to include(:first_diagnosis)
      end

      it "初診断イベントのタイトルが正しい" do
        item = result.timeline_items.find { |i| i.type == :first_diagnosis }
        expect(item.title).to eq("はじめて歌唱診断を実施")
      end

      it "初診断イベントのアイコンが 🎤 である" do
        item = result.timeline_items.find { |i| i.type == :first_diagnosis }
        expect(item.icon).to eq("🎤")
      end

      it "初診断イベントに description がある" do
        item = result.timeline_items.find { |i| i.type == :first_diagnosis }
        expect(item.description).to include("65点")
      end

      it "occurred_at が Date である" do
        item = result.timeline_items.find { |i| i.type == :first_diagnosis }
        expect(item.occurred_at).to be_a(Date)
      end
    end

    context "自己ベスト更新がある場合" do
      before do
        make_diagnosis(score: 60, created_at: 20.days.ago)
        make_diagnosis(score: 70, created_at: 10.days.ago)
        make_diagnosis(score: 65, created_at: 5.days.ago)
      end

      it "自己ベストイベントが含まれる" do
        expect(result.timeline_items.map(&:type)).to include(:personal_best)
      end

      it "自己ベストイベントのタイトルが正しい" do
        item = result.timeline_items.find { |i| i.type == :personal_best }
        expect(item.title).to eq("自己ベスト更新")
      end

      it "自己ベストイベントのアイコンが ⭐ である" do
        item = result.timeline_items.find { |i| i.type == :personal_best }
        expect(item.icon).to eq("⭐")
      end

      it "自己ベストイベントにスコアが含まれる" do
        item = result.timeline_items.find { |i| i.type == :personal_best }
        expect(item.description).to include("70点")
      end

      it "自己ベストでない診断はイベントにならない" do
        expect(result.timeline_items.select { |i| i.type == :personal_best }.size).to eq(1)
      end

      it "初診断は自己ベストイベントにならない" do
        personal_best_dates = result.timeline_items.select { |i| i.type == :personal_best }.map(&:occurred_at)
        expect(personal_best_dates).not_to include(20.days.ago.to_date)
      end
    end

    context "7日連続記録がある場合" do
      before do
        7.times { |i| make_diagnosis(score: 65, created_at: (8 - i).days.ago) }
      end

      it "streak_milestone イベントが含まれる" do
        expect(result.timeline_items.map(&:type)).to include(:streak_milestone)
      end

      it "7日継続達成のタイトルが正しい" do
        item = result.timeline_items.find { |i| i.type == :streak_milestone }
        expect(item.title).to eq("7日継続達成")
      end

      it "streak_milestone イベントのアイコンが 🔥 である" do
        item = result.timeline_items.find { |i| i.type == :streak_milestone }
        expect(item.icon).to eq("🔥")
      end

      it "streak_milestone に description がある" do
        item = result.timeline_items.find { |i| i.type == :streak_milestone }
        expect(item.description).to be_present
      end
    end

    context "30日連続記録がある場合" do
      before do
        30.times { |i| make_diagnosis(score: 65, created_at: (31 - i).days.ago) }
      end

      it "7日継続と30日継続の両方が含まれる" do
        streak_titles = result.timeline_items.select { |i| i.type == :streak_milestone }.map(&:title)
        expect(streak_titles).to include("7日継続達成", "30日継続達成")
      end

      it "streak_milestone が 2件だけある" do
        expect(result.timeline_items.select { |i| i.type == :streak_milestone }.size).to eq(2)
      end
    end

    context "連続でない診断が7件ある場合" do
      before do
        7.times { |i| make_diagnosis(score: 65, created_at: (i * 3).days.ago) }
      end

      it "streak_milestone イベントが含まれない" do
        expect(result.timeline_items.map(&:type)).not_to include(:streak_milestone)
      end
    end

    context "timeline_items のソート順" do
      before do
        make_diagnosis(score: 60, created_at: 30.days.ago)
        make_diagnosis(score: 80, created_at: 5.days.ago)
      end

      it "新しい順（DESC）で返る" do
        dates = result.timeline_items.map(&:occurred_at)
        expect(dates).to eq(dates.sort.reverse)
      end
    end

    context "TimelineItem DTO" do
      before { make_diagnosis(score: 65, created_at: 1.day.ago) }

      subject(:item) { result.timeline_items.first }

      it "type が Symbol である" do
        expect(item.type).to be_a(Symbol)
      end

      it "title が String である" do
        expect(item.title).to be_a(String)
      end

      it "icon が String である" do
        expect(item.icon).to be_a(String)
      end

      it "occurred_at が Date である" do
        expect(item.occurred_at).to be_a(Date)
      end
    end
  end
end
