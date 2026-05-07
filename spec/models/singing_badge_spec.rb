require "rails_helper"

RSpec.describe SingingBadge, type: :model do
  describe "バリデーション" do
    it "有効なバッジは保存できること" do
      badge = FactoryBot.build(:singing_badge)
      expect(badge).to be_valid
    end

    it "badge_type が BADGE_TYPES 外は無効であること" do
      badge = FactoryBot.build(:singing_badge, badge_type: "unknown_type")
      expect(badge).not_to be_valid
      expect(badge.errors[:badge_type]).to be_present
    end

    it "awarded_at が nil は無効であること" do
      badge = FactoryBot.build(:singing_badge, awarded_at: nil)
      expect(badge).not_to be_valid
    end

    it "同一 customer / season / badge_type の重複は保存できないこと" do
      season   = FactoryBot.create(:singing_ranking_season)
      customer = FactoryBot.create(:customer, domain_name: "singing")
      FactoryBot.create(:singing_badge, customer: customer, singing_ranking_season: season, badge_type: "season_1st")
      duplicate = FactoryBot.build(:singing_badge, customer: customer, singing_ranking_season: season, badge_type: "season_1st")
      expect(duplicate).not_to be_valid
    end
  end

  describe "#label" do
    it "badge_type に対応するラベルを返すこと" do
      expect(FactoryBot.build(:singing_badge, badge_type: "season_1st").label).to eq "今月の王者"
      expect(FactoryBot.build(:singing_badge, badge_type: "rapid_growth").label).to eq "急成長シンガー"
      expect(FactoryBot.build(:singing_badge, badge_type: "consecutive_participation").label).to eq "継続の証"
    end
  end

  describe "#emoji" do
    it "badge_type に対応する絵文字を返すこと" do
      expect(FactoryBot.build(:singing_badge, badge_type: "season_1st").emoji).to eq "🥇"
      expect(FactoryBot.build(:singing_badge, badge_type: "season_2nd").emoji).to eq "🥈"
      expect(FactoryBot.build(:singing_badge, badge_type: "rapid_growth").emoji).to eq "📈"
    end
  end

  describe "#display_text" do
    it "絵文字とラベルを結合して返すこと" do
      badge = FactoryBot.build(:singing_badge, badge_type: "season_top10")
      expect(badge.display_text).to eq "🎯 TOP10入り"
    end
  end
end
