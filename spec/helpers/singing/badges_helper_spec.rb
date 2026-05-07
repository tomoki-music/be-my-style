require "rails_helper"

RSpec.describe Singing::BadgesHelper, type: :helper do
  let(:season) do
    FactoryBot.create(
      :singing_ranking_season,
      name: "2026年4月シーズン",
      status: "closed",
      starts_on: Date.new(2026, 4, 1),
      ends_on: Date.new(2026, 4, 30)
    )
  end

  def build_badge(badge_type:, awarded_at: Time.current)
    FactoryBot.build(
      :singing_badge,
      badge_type: badge_type,
      singing_ranking_season: season,
      awarded_at: awarded_at
    )
  end

  describe "#singing_badge_label" do
    it "badge_type に対応するラベルを返すこと" do
      expect(helper.singing_badge_label(build_badge(badge_type: "season_1st"))).to eq "今月の王者"
      expect(helper.singing_badge_label(build_badge(badge_type: "rapid_growth"))).to eq "急成長シンガー"
      expect(helper.singing_badge_label(build_badge(badge_type: "consecutive_participation"))).to eq "継続の証"
    end
  end

  describe "#singing_badge_emoji" do
    it "badge_type に対応する絵文字を返すこと" do
      expect(helper.singing_badge_emoji(build_badge(badge_type: "season_1st"))).to eq "🥇"
      expect(helper.singing_badge_emoji(build_badge(badge_type: "season_2nd"))).to eq "🥈"
      expect(helper.singing_badge_emoji(build_badge(badge_type: "season_top3"))).to eq "🥉"
      expect(helper.singing_badge_emoji(build_badge(badge_type: "season_top10"))).to eq "🎯"
      expect(helper.singing_badge_emoji(build_badge(badge_type: "rapid_growth"))).to eq "📈"
      expect(helper.singing_badge_emoji(build_badge(badge_type: "consecutive_participation"))).to eq "🔥"
    end
  end

  describe "#singing_badge_display_text" do
    it "絵文字とラベルを結合して返すこと" do
      badge = build_badge(badge_type: "season_top10")
      expect(helper.singing_badge_display_text(badge)).to eq "🎯 TOP10入り"
    end
  end

  describe "#singing_badge_season_name" do
    it "シーズン名を返すこと" do
      badge = build_badge(badge_type: "season_1st")
      expect(helper.singing_badge_season_name(badge)).to eq "2026年4月シーズン"
    end
  end

  describe "#singing_badge_new?" do
    it "awarded_at が7日以内なら true を返すこと" do
      badge = build_badge(badge_type: "season_1st", awarded_at: 3.days.ago)
      expect(helper.singing_badge_new?(badge)).to be true
    end

    it "awarded_at が7日より古いなら false を返すこと" do
      badge = build_badge(badge_type: "season_1st", awarded_at: 8.days.ago)
      expect(helper.singing_badge_new?(badge)).to be false
    end

    it "awarded_at が今日なら true を返すこと" do
      badge = build_badge(badge_type: "season_1st", awarded_at: Time.current)
      expect(helper.singing_badge_new?(badge)).to be true
    end
  end
end
