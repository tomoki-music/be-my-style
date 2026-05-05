require 'rails_helper'

RSpec.describe "Admin::SingingRankingSeasons", type: :request do
  let(:admin)    { FactoryBot.create(:admin) }
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let!(:season)  { FactoryBot.create(:singing_ranking_season, name: "2026年5月シーズン", status: "draft") }

  describe "管理者ログイン済み" do
    before { sign_in admin }

    describe "GET /admin/singing_ranking_seasons (index)" do
      it "200 OK を返すこと" do
        get admin_singing_ranking_seasons_path
        expect(response).to have_http_status(:ok)
      end

      it "シーズン名を表示すること" do
        get admin_singing_ranking_seasons_path
        expect(response.body).to include("2026年5月シーズン")
      end

      it "ステータスバッジを表示すること" do
        get admin_singing_ranking_seasons_path
        expect(response.body).to include("準備中")
      end

      it "active シーズンを「開催中」として表示すること" do
        active = FactoryBot.create(:singing_ranking_season, status: "active")
        get admin_singing_ranking_seasons_path
        expect(response.body).to include("開催中")
      end

      it "新規作成リンクを含むこと" do
        get admin_singing_ranking_seasons_path
        expect(response.body).to include(new_admin_singing_ranking_season_path)
      end
    end

    describe "GET /admin/singing_ranking_seasons/:id (show)" do
      it "200 OK を返すこと" do
        get admin_singing_ranking_season_path(season)
        expect(response).to have_http_status(:ok)
      end

      it "シーズン名を表示すること" do
        get admin_singing_ranking_season_path(season)
        expect(response.body).to include("2026年5月シーズン")
      end

      it "Entries 数を表示すること" do
        FactoryBot.create(:singing_season_ranking_entry,
                          singing_ranking_season: season,
                          customer: customer,
                          rank: 1, score: 90)
        get admin_singing_ranking_season_path(season)
        expect(response.body).to include("1")
      end

      it "Entries が 0 件でも落ちないこと" do
        get admin_singing_ranking_season_path(season)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("0")
      end

      it "ユーザー向けページへのリンクを含むこと" do
        get admin_singing_ranking_season_path(season)
        expect(response.body).to include(singing_ranking_season_path(season))
      end

      it "再集計導線を表示すること" do
        get admin_singing_ranking_season_path(season)
        expect(response.body).to include("再集計する")
        expect(response.body).to include("対象期間内の診断結果からランキングを作り直します")
        expect(response.body).to include("既存の overall/pitch/rhythm/expression entries は置き換えられます")
      end
    end

    describe "GET /admin/singing_ranking_seasons/new (new)" do
      it "200 OK を返すこと" do
        get new_admin_singing_ranking_season_path
        expect(response).to have_http_status(:ok)
      end

      it "フォームを表示すること" do
        get new_admin_singing_ranking_season_path
        expect(response.body).to include("シーズン名")
      end

      it "status の select を含むこと" do
        get new_admin_singing_ranking_season_path
        expect(response.body).to include("draft").or include("active")
      end
    end

    describe "POST /admin/singing_ranking_seasons (create)" do
      let(:valid_params) do
        {
          singing_ranking_season: {
            name: "2026年6月シーズン",
            starts_on: "2026-06-01",
            ends_on: "2026-06-30",
            status: "draft",
            season_type: "monthly"
          }
        }
      end

      it "シーズンを作成して show にリダイレクトすること" do
        expect {
          post admin_singing_ranking_seasons_path, params: valid_params
        }.to change(SingingRankingSeason, :count).by(1)
        expect(response).to redirect_to(admin_singing_ranking_season_path(SingingRankingSeason.last))
      end

      it "バリデーションエラー時は new を再表示すること" do
        invalid_params = { singing_ranking_season: { name: "", starts_on: "2026-06-01", ends_on: "2026-06-30", status: "draft", season_type: "monthly" } }
        post admin_singing_ranking_seasons_path, params: invalid_params
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("alert-danger").or include("入力してください")
      end

      it "ends_on が starts_on より前の場合バリデーションエラーになること" do
        invalid_params = { singing_ranking_season: { name: "テスト", starts_on: "2026-06-30", ends_on: "2026-06-01", status: "draft", season_type: "monthly" } }
        post admin_singing_ranking_seasons_path, params: invalid_params
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /admin/singing_ranking_seasons/:id/edit (edit)" do
      it "200 OK を返すこと" do
        get edit_admin_singing_ranking_season_path(season)
        expect(response).to have_http_status(:ok)
      end

      it "既存のシーズン名がフォームに入っていること" do
        get edit_admin_singing_ranking_season_path(season)
        expect(response.body).to include("2026年5月シーズン")
      end
    end

    describe "PATCH /admin/singing_ranking_seasons/:id (update)" do
      it "更新して show にリダイレクトすること" do
        patch admin_singing_ranking_season_path(season), params: {
          singing_ranking_season: {
            name: "更新後シーズン",
            starts_on: season.starts_on,
            ends_on: season.ends_on,
            status: "active",
            season_type: "monthly"
          }
        }
        expect(response).to redirect_to(admin_singing_ranking_season_path(season))
        expect(season.reload.status).to eq "active"
        expect(season.reload.name).to eq "更新後シーズン"
      end

      it "バリデーションエラー時は edit を再表示すること" do
        patch admin_singing_ranking_season_path(season), params: {
          singing_ranking_season: {
            name: "",
            starts_on: season.starts_on,
            ends_on: season.ends_on,
            status: "draft",
            season_type: "monthly"
          }
        }
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /admin/singing_ranking_seasons/:id/aggregate" do
      it "ランキングを再集計して show にリダイレクトすること" do
        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: customer,
          diagnosed_at: season.starts_on.to_time + 12.hours,
          overall_score: 88
        )

        expect {
          post aggregate_admin_singing_ranking_season_path(season)
        }.to change(SingingSeasonRankingEntry, :count).by(4)

        expect(response).to redirect_to(admin_singing_ranking_season_path(season))
        follow_redirect!
        expect(response.body).to include("シーズンランキングを再集計しました")
      end
    end
  end

  describe "非管理者のアクセス" do
    shared_examples "管理者画面にアクセスできない" do
      it "index にアクセスできないこと" do
        get admin_singing_ranking_seasons_path
        expect(response).not_to have_http_status(:ok)
      end

      it "show にアクセスできないこと" do
        get admin_singing_ranking_season_path(season)
        expect(response).not_to have_http_status(:ok)
      end

      it "new にアクセスできないこと" do
        get new_admin_singing_ranking_season_path
        expect(response).not_to have_http_status(:ok)
      end

      it "create にアクセスできないこと" do
        expect {
          post admin_singing_ranking_seasons_path, params: {
            singing_ranking_season: {
              name: "非管理者作成",
              starts_on: "2026-06-01",
              ends_on: "2026-06-30",
              status: "draft",
              season_type: "monthly"
            }
          }
        }.not_to change(SingingRankingSeason, :count)
        expect(response).not_to have_http_status(:ok)
      end

      it "edit にアクセスできないこと" do
        get edit_admin_singing_ranking_season_path(season)
        expect(response).not_to have_http_status(:ok)
      end

      it "update にアクセスできないこと" do
        patch admin_singing_ranking_season_path(season), params: {
          singing_ranking_season: {
            name: "非管理者更新",
            starts_on: season.starts_on,
            ends_on: season.ends_on,
            status: "active",
            season_type: "monthly"
          }
        }
        expect(response).not_to have_http_status(:ok)
        expect(season.reload.name).to eq "2026年5月シーズン"
      end

      it "aggregate できないこと" do
        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: customer,
          diagnosed_at: season.starts_on.to_time + 12.hours,
          overall_score: 88
        )

        expect {
          post aggregate_admin_singing_ranking_season_path(season)
        }.not_to change(SingingSeasonRankingEntry, :count)
        expect(response).not_to have_http_status(:ok)
      end
    end

    context "管理者未ログイン" do
      it_behaves_like "管理者画面にアクセスできない"
    end

    context "一般ユーザーでログイン済み" do
      before { sign_in customer }

      it_behaves_like "管理者画面にアクセスできない"
    end
  end
end
