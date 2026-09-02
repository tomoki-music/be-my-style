require 'rails_helper'

RSpec.describe PerformanceRankings::Period do
  include ActiveSupport::Testing::TimeHelpers

  # config.time_zone = "Tokyo"。基準日を固定して境界を検証する。
  around do |example|
    travel_to(Time.zone.local(2026, 9, 15, 10, 0, 0)) { example.run }
  end

  describe "プリセット" do
    it "今月は当月初日0時から翌月初日0時まで(半開区間)" do
      range = described_class.new(preset: "this_month").range
      expect(range.first).to eq Time.zone.local(2026, 9, 1)
      expect(range.last).to eq Time.zone.local(2026, 10, 1)
    end

    it "先月は前月初日0時から当月初日0時まで" do
      range = described_class.new(preset: "last_month").range
      expect(range.first).to eq Time.zone.local(2026, 8, 1)
      expect(range.last).to eq Time.zone.local(2026, 9, 1)
    end

    it "今年は当年初日0時から翌年初日0時まで" do
      range = described_class.new(preset: "this_year").range
      expect(range.first).to eq Time.zone.local(2026, 1, 1)
      expect(range.last).to eq Time.zone.local(2027, 1, 1)
    end

    it "過去1年間は今日を含む直近1年(翌日0時が上限)" do
      range = described_class.new(preset: "past_year").range
      expect(range.first).to eq Time.zone.local(2025, 9, 16)
      expect(range.last).to eq Time.zone.local(2026, 9, 16)
    end

    it "全期間はnil(期間で絞り込まない)" do
      expect(described_class.new(preset: "all").range).to be_nil
    end

    it "未知のプリセットは全期間扱いになること" do
      period = described_class.new(preset: "yesterday_only")
      expect(period.preset).to eq "all"
      expect(period.range).to be_nil
    end
  end

  describe "カスタム期間" do
    it "開始日0時から終了日翌日0時まで(開始日・終了日を含む)" do
      range = described_class.new(preset: "custom", start_on: "2026-03-01", end_on: "2026-03-31").range
      expect(range.first).to eq Time.zone.local(2026, 3, 1)
      expect(range.last).to eq Time.zone.local(2026, 4, 1)
    end

    it "開始日が終了日より後なら invalid? が true で range は nil" do
      period = described_class.new(preset: "custom", start_on: "2026-03-31", end_on: "2026-03-01")
      expect(period).to be_invalid
      expect(period.range).to be_nil
    end

    it "同一日なら invalid ではなくその日1日分になること" do
      period = described_class.new(preset: "custom", start_on: "2026-03-10", end_on: "2026-03-10")
      expect(period).not_to be_invalid
      expect(period.range).to eq [Time.zone.local(2026, 3, 10), Time.zone.local(2026, 3, 11)]
    end

    it "存在しない日付・不正な文字列でも例外を出さず nil として扱うこと" do
      period = described_class.new(preset: "custom", start_on: "2026-02-30", end_on: "not-a-date")
      expect { period.range }.not_to raise_error
      expect(period.start_on).to be_nil
      expect(period.end_on).to be_nil
      expect(period.range).to be_nil
      expect(period).not_to be_invalid
    end

    it "片方だけ指定した場合は指定側だけを境界にすること" do
      range = described_class.new(preset: "custom", start_on: "2026-05-01", end_on: nil).range
      expect(range.first).to eq Time.zone.local(2026, 5, 1)
      expect(range.last).to be_nil
    end
  end
end
