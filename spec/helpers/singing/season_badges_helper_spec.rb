require "rails_helper"

RSpec.describe Singing::SeasonBadgesHelper, type: :helper do
  describe "#season_badge_label" do
    it "badge_key に応じたラベルを返すこと" do
      expect(helper.season_badge_label("monthly_overall_top_1")).to eq "月間トップシンガー"
      expect(helper.season_badge_label("monthly_pitch_top_1")).to eq "Pitchリーダー"
    end

    it "unknown badge_key は title を優先し、title がなければ nil を返すこと" do
      expect(helper.season_badge_label("unknown_badge", title: "継続チャレンジャー")).to eq "継続チャレンジャー"
      expect(helper.season_badge_label("unknown_badge")).to be_nil
    end
  end

  describe "#season_badge_emoji" do
    it "badge_key に応じた絵文字を返すこと" do
      expect(helper.season_badge_emoji("monthly_overall_top_3")).to eq "🥇"
      expect(helper.season_badge_emoji("monthly_rhythm_top_1")).to eq "🥁"
    end

    it "unknown badge_key で落ちないこと" do
      expect(helper.season_badge_emoji("unknown_badge")).to be_nil
    end
  end

  describe "#season_category_label" do
    it "カテゴリの表示名を返すこと" do
      expect(helper.season_category_label("overall")).to eq "総合ランキング"
      expect(helper.season_category_label("expression")).to eq "表現力ランキング"
    end
  end
end
