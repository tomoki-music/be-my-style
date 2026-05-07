require "rails_helper"

RSpec.describe "Singing::SeasonHistories", type: :request do
  let(:customer) { create(:customer, domain_name: "singing") }

  describe "GET /singing/season_histories" do
    context "未ログインの場合" do
      it "ログインページへリダイレクトされること" do
        get singing_season_histories_path

        expect(response).to redirect_to(new_customer_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in customer }

      context "シーズンが存在しない場合" do
        it "200 OK でページが表示され、空状態メッセージが出ること" do
          get singing_season_histories_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("あなたのシーズン履歴")
          expect(response.body).to include("まだシーズンが開催されていません")
        end
      end

      context "開催中シーズンが存在するが未参加の場合" do
        let!(:active_season) do
          create(:singing_ranking_season, :current,
                 name: "2026年5月シーズン")
        end

        it "シーズン名と未参加メッセージが表示されること" do
          get singing_season_histories_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("2026年5月シーズン")
          expect(response.body).to include("開催中")
          expect(response.body).to include("まだ参加していません")
          expect(response.body).to include("今月まだ間に合います")
        end

        it "診断を始めるCTAリンクが表示されること" do
          get singing_season_histories_path

          expect(response.body).to include("今月の診断を始める")
        end
      end

      context "開催中シーズンに参加済みの場合" do
        let!(:active_season) do
          create(:singing_ranking_season, :current,
                 name: "2026年5月シーズン")
        end
        let!(:entry) do
          create(:singing_season_ranking_entry,
                 singing_ranking_season: active_season,
                 customer: customer,
                 category: "overall",
                 rank: 3,
                 score: 85)
        end

        it "順位とスコアが表示されること" do
          get singing_season_histories_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("3位")
          expect(response.body).to include("85")
          expect(response.body).to include("今月のランキングに挑戦中")
        end
      end

      context "終了済みシーズンに参加済みでバッジを獲得している場合" do
        let!(:closed_season) do
          create(:singing_ranking_season, :closed,
                 name: "2026年4月シーズン")
        end
        let!(:entry) do
          create(:singing_season_ranking_entry,
                 singing_ranking_season: closed_season,
                 customer: customer,
                 category: "overall",
                 rank: 1,
                 score: 92)
        end
        let!(:badge) do
          create(:singing_badge,
                 customer: customer,
                 singing_ranking_season: closed_season,
                 badge_type: "season_1st",
                 awarded_at: 10.days.ago)
        end

        it "順位・スコア・バッジが表示されること" do
          get singing_season_histories_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("2026年4月シーズン")
          expect(response.body).to include("終了")
          expect(response.body).to include("1位")
          expect(response.body).to include("92")
          expect(response.body).to include("🥇")
          expect(response.body).to include("今月の王者")
        end
      end

      context "終了済みシーズンに未参加の場合" do
        let!(:closed_season) do
          create(:singing_ranking_season, :closed,
                 name: "2026年4月シーズン")
        end

        it "未参加メッセージと再挑戦を促す文言が表示されること" do
          get singing_season_histories_path

          expect(response.body).to include("まだ参加していません")
          expect(response.body).to include("次のシーズンで挑戦してみましょう")
        end

        it "終了シーズンに診断CTAボタンは表示されないこと" do
          get singing_season_histories_path

          expect(response.body).not_to include("今月の診断を始める")
        end
      end

      context "複数シーズンが存在する場合（N+1 チェック）" do
        let!(:season_a) { create(:singing_ranking_season, :closed, name: "2026年3月シーズン") }
        let!(:season_b) { create(:singing_ranking_season, :closed, name: "2026年4月シーズン") }
        let!(:season_c) { create(:singing_ranking_season, :current, name: "2026年5月シーズン") }

        before do
          create(:singing_season_ranking_entry,
                 singing_ranking_season: season_a, customer: customer,
                 category: "overall", rank: 5, score: 70)
          create(:singing_badge,
                 customer: customer, singing_ranking_season: season_a,
                 badge_type: "season_top10", awarded_at: 60.days.ago)
          create(:singing_season_ranking_entry,
                 singing_ranking_season: season_c, customer: customer,
                 category: "overall", rank: 2, score: 88)
        end

        it "全シーズンが正常に表示されること" do
          get singing_season_histories_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("2026年3月シーズン")
          expect(response.body).to include("2026年4月シーズン")
          expect(response.body).to include("2026年5月シーズン")
        end

        it "参加済みシーズンのデータが表示されること" do
          get singing_season_histories_path

          expect(response.body).to include("5位")
          expect(response.body).to include("🎯")
          expect(response.body).to include("2位")
          expect(response.body).to include("88")
        end

        it "未参加シーズンには未参加メッセージが表示されること" do
          get singing_season_histories_path

          expect(response.body).to include("まだ参加していません")
        end
      end

      context "他ユーザーのエントリは表示されないこと" do
        let(:other_customer) { create(:customer, domain_name: "singing") }
        let!(:active_season) { create(:singing_ranking_season, :current, name: "2026年5月シーズン") }
        let!(:other_entry) do
          create(:singing_season_ranking_entry,
                 singing_ranking_season: active_season,
                 customer: other_customer,
                 category: "overall",
                 rank: 1,
                 score: 99)
        end

        it "自分が未参加であれば他ユーザーのスコアは表示されないこと" do
          get singing_season_histories_path

          expect(response.body).not_to include("99")
          expect(response.body).to include("まだ参加していません")
        end
      end

      context "ナビゲーションリンク" do
        it "バッジ一覧へのリンクが含まれること" do
          get singing_season_histories_path

          expect(response.body).to include(singing_badges_path)
        end

        it "ランキングへのリンクが含まれること" do
          get singing_season_histories_path

          expect(response.body).to include(singing_rankings_path)
        end
      end
    end
  end
end
