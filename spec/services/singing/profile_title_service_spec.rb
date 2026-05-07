require "rails_helper"

RSpec.describe Singing::ProfileTitleService do
  def build_badges(*badge_types)
    badge_types.map { |type| instance_double(SingingBadge, badge_type: type.to_s) }
  end

  describe ".call" do
    context "season_1st バッジを持つ場合" do
      it "「今月の王者」称号を返すこと" do
        title = described_class.call(build_badges("season_1st"))

        expect(title.key).to eq(:season_1st)
        expect(title.label).to eq("今月の王者")
        expect(title.icon).to eq("🥇")
        expect(title.description).to be_present
      end
    end

    context "season_2nd バッジを持つ場合" do
      it "「準優勝シンガー」称号を返すこと" do
        title = described_class.call(build_badges("season_2nd"))

        expect(title.key).to eq(:season_2nd)
        expect(title.label).to eq("準優勝シンガー")
        expect(title.icon).to eq("🥈")
      end
    end

    context "season_top3 バッジを持つ場合" do
      it "「TOP3シンガー」称号を返すこと" do
        title = described_class.call(build_badges("season_top3"))

        expect(title.key).to eq(:season_top3)
        expect(title.label).to eq("TOP3シンガー")
        expect(title.icon).to eq("🥉")
      end
    end

    context "season_top10 バッジを持つ場合" do
      it "「TOP10シンガー」称号を返すこと" do
        title = described_class.call(build_badges("season_top10"))

        expect(title.key).to eq(:season_top10)
        expect(title.label).to eq("TOP10シンガー")
        expect(title.icon).to eq("🎯")
      end
    end

    context "rapid_growth バッジを持つ場合" do
      it "「急成長シンガー」称号を返すこと" do
        title = described_class.call(build_badges("rapid_growth"))

        expect(title.key).to eq(:rapid_growth)
        expect(title.label).to eq("急成長シンガー")
        expect(title.icon).to eq("📈")
      end
    end

    context "consecutive_participation バッジを持つ場合" do
      it "「継続チャレンジャー」称号を返すこと" do
        title = described_class.call(build_badges("consecutive_participation"))

        expect(title.key).to eq(:consecutive_participation)
        expect(title.label).to eq("継続チャレンジャー")
        expect(title.icon).to eq("🔥")
      end
    end

    context "称号対象外のバッジが3個以上ある場合" do
      it "「バッジコレクター」称号を返すこと" do
        badges = [
          instance_double(SingingBadge, badge_type: "future_badge_a"),
          instance_double(SingingBadge, badge_type: "future_badge_b"),
          instance_double(SingingBadge, badge_type: "future_badge_c")
        ]
        title = described_class.call(badges)

        expect(title.key).to eq(:badge_collector)
        expect(title.label).to eq("バッジコレクター")
        expect(title.icon).to eq("🎖️")
      end
    end

    context "称号対象外のバッジが2個以下の場合" do
      it "「挑戦者」称号を返すこと" do
        badges = [
          instance_double(SingingBadge, badge_type: "future_badge_a"),
          instance_double(SingingBadge, badge_type: "future_badge_b")
        ]
        title = described_class.call(badges)

        expect(title.key).to eq(:challenger)
        expect(title.label).to eq("挑戦者")
        expect(title.icon).to eq("🎵")
      end
    end

    context "バッジが0件の場合" do
      it "「挑戦者」称号を返すこと" do
        title = described_class.call([])

        expect(title.key).to eq(:challenger)
        expect(title.label).to eq("挑戦者")
      end
    end

    context "優先順位のテスト" do
      it "season_1st は他のバッジより優先されること" do
        badges = build_badges("consecutive_participation", "rapid_growth", "season_1st")
        title = described_class.call(badges)

        expect(title.key).to eq(:season_1st)
      end

      it "season_2nd は season_top3 より優先されること" do
        badges = build_badges("season_top3", "season_2nd")
        title = described_class.call(badges)

        expect(title.key).to eq(:season_2nd)
      end

      it "rapid_growth は consecutive_participation より優先されること" do
        badges = build_badges("consecutive_participation", "rapid_growth")
        title = described_class.call(badges)

        expect(title.key).to eq(:rapid_growth)
      end
    end
  end
end
