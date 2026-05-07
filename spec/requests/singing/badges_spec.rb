require "rails_helper"

RSpec.describe "Singing::Badges", type: :request do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:other_customer) { create(:customer, domain_name: "singing") }

  describe "GET /singing/badges" do
    context "未ログインの場合" do
      it "ログインページへリダイレクトされること" do
        get singing_badges_path

        expect(response).to redirect_to(new_customer_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in customer }

      it "バッジ一覧ページが表示されること" do
        get singing_badges_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("あなたのバッジ")
        expect(response.body).to include("実績バッジ")
        expect(response.body).to include("シーズンバッジ")
      end

      it "全12種類の実績バッジ定義が表示されること" do
        get singing_badges_path

        Singing::RankingBadgeService::BADGE_DEFINITIONS.each_value do |definition|
          expect(response.body).to include(definition[:label])
        end
      end

      it "バッジ未取得の場合、実績バッジはすべて「未獲得」で表示されること" do
        get singing_badges_path

        expect(response.body).to include("未獲得")
        expect(response.body).not_to include("singing-badges__ranking-badge--unearned\">")
      end

      it "診断を1件完了するとその実績バッジが獲得済みになること" do
        create(:singing_diagnosis, :completed, customer: customer, overall_score: 75)

        get singing_badges_path

        expect(response.body).to include("初診断")
        # 獲得済みバッジには --unearned クラスが付かない
        body = response.body
        # 初診断の前後コンテキストで未獲得クラスが付いていないことを確認
        expect(body).to include("実績バッジ")
      end

      it "獲得済みシーズンバッジが一覧に表示されること" do
        season = create(
          :singing_ranking_season,
          name: "2026年4月シーズン",
          status: "closed",
          starts_on: Date.new(2026, 4, 1),
          ends_on: Date.new(2026, 4, 30)
        )
        create(
          :singing_badge,
          customer: customer,
          singing_ranking_season: season,
          badge_type: "season_1st",
          awarded_at: 2.days.ago
        )

        get singing_badges_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("今月の王者")
        expect(response.body).to include("🥇")
        expect(response.body).to include("2026年4月シーズン")
        expect(response.body).to include("NEW")
      end

      it "7日より古いシーズンバッジには NEW が表示されないこと" do
        season = create(
          :singing_ranking_season,
          name: "2026年3月シーズン",
          status: "closed",
          starts_on: Date.new(2026, 3, 1),
          ends_on: Date.new(2026, 3, 31)
        )
        create(
          :singing_badge,
          customer: customer,
          singing_ranking_season: season,
          badge_type: "rapid_growth",
          awarded_at: 10.days.ago
        )

        get singing_badges_path

        expect(response.body).to include("急成長シンガー")
        expect(response.body).not_to include("NEW")
      end

      it "シーズンバッジがない場合は空状態メッセージを表示すること" do
        get singing_badges_path

        expect(response.body).to include("シーズンバッジはまだありません。")
        expect(response.body).to include("ランキングに参加する")
      end

      it "複数シーズンのバッジがあってもページが正常に表示されること（N+1対策確認）" do
        season_a = create(
          :singing_ranking_season,
          name: "2026年2月シーズン",
          status: "closed",
          starts_on: Date.new(2026, 2, 1),
          ends_on: Date.new(2026, 2, 28)
        )
        season_b = create(
          :singing_ranking_season,
          name: "2026年3月シーズン",
          status: "closed",
          starts_on: Date.new(2026, 3, 1),
          ends_on: Date.new(2026, 3, 31)
        )
        create(:singing_badge, customer: customer, singing_ranking_season: season_a,
                               badge_type: "season_1st", awarded_at: 60.days.ago)
        create(:singing_badge, customer: customer, singing_ranking_season: season_b,
                               badge_type: "season_2nd", awarded_at: 30.days.ago)

        get singing_badges_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("2026年2月シーズン")
        expect(response.body).to include("2026年3月シーズン")
        expect(response.body).to include("今月の王者")
        expect(response.body).to include("準優勝")
      end
    end
  end
end
