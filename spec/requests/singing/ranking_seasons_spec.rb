require 'rails_helper'

RSpec.describe "Singing::RankingSeasons", type: :request do
  let(:singing_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let!(:singing_domain)  { Domain.find_or_create_by!(name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: singing_customer, domain: singing_domain)
    sign_in singing_customer
  end

  describe "GET /singing/ranking_seasons" do
    context "current season が存在する場合" do
      let!(:current_season) { FactoryBot.create(:singing_ranking_season, :current) }

      it "200 OK を返すこと" do
        get singing_ranking_seasons_path
        expect(response).to have_http_status(:ok)
      end

      it "current season の名前を表示すること" do
        get singing_ranking_seasons_path
        expect(response.body).to include(current_season.name)
      end

      it "「今月開催中」を表示すること" do
        get singing_ranking_seasons_path
        expect(response.body).to include("今月開催中")
      end

      it "シーズン詳細ページへのリンクを含むこと" do
        get singing_ranking_seasons_path
        expect(response.body).to include(singing_ranking_season_path(current_season))
      end
    end

    context "current season が存在しない場合" do
      let!(:closed_season) { FactoryBot.create(:singing_ranking_season, :closed) }

      it "200 OK を返すこと（落ちないこと）" do
        get singing_ranking_seasons_path
        expect(response).to have_http_status(:ok)
      end

      it "「現在開催中のシーズンはありません」を表示すること" do
        get singing_ranking_seasons_path
        expect(response.body).to include("現在開催中のシーズンはありません")
      end
    end

    context "シーズンが一つも存在しない場合" do
      it "200 OK を返すこと（落ちないこと）" do
        get singing_ranking_seasons_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "draft シーズンのみの場合" do
      let!(:draft_season) { FactoryBot.create(:singing_ranking_season, :draft) }

      it "draft シーズンは一覧に表示しないこと" do
        get singing_ranking_seasons_path
        expect(response.body).not_to include(draft_season.name)
      end
    end

    context "複数シーズンがある場合" do
      let!(:current_season) { FactoryBot.create(:singing_ranking_season, :current) }
      let!(:closed_season)  { FactoryBot.create(:singing_ranking_season, :closed) }

      it "closed シーズンも一覧に表示すること" do
        get singing_ranking_seasons_path
        expect(response.body).to include(closed_season.name)
      end
    end
  end

  describe "GET /singing/ranking_seasons/:id" do
    context "エントリーが存在しないシーズン" do
      let!(:season) { FactoryBot.create(:singing_ranking_season) }

      it "200 OK を返すこと" do
        get singing_ranking_season_path(season)
        expect(response).to have_http_status(:ok)
      end

      it "シーズン名を表示すること" do
        get singing_ranking_season_path(season)
        expect(response.body).to include(season.name)
      end

      it "エントリーなしの場合でも落ちないこと" do
        get singing_ranking_season_path(season)
        expect(response).to have_http_status(:ok)
      end
    end

    context "エントリーが存在するシーズン" do
      let!(:season)  { FactoryBot.create(:singing_ranking_season) }
      let!(:other1)  { FactoryBot.create(:customer, domain_name: "singing") }
      let!(:other2)  { FactoryBot.create(:customer, domain_name: "singing") }
      let!(:entry1)  do
        FactoryBot.create(:singing_season_ranking_entry,
                          singing_ranking_season: season,
                          customer: other1,
                          rank: 1, score: 95, category: "overall",
                          title: "月間TOPシンガー", badge_key: "monthly_overall_top_1")
      end
      let!(:entry2)  do
        FactoryBot.create(:singing_season_ranking_entry,
                          singing_ranking_season: season,
                          customer: other2,
                          rank: 2, score: 88, category: "overall")
      end

      before do
        CustomerDomain.find_or_create_by!(customer: other1, domain: singing_domain)
        CustomerDomain.find_or_create_by!(customer: other2, domain: singing_domain)
      end

      it "200 OK を返すこと" do
        get singing_ranking_season_path(season)
        expect(response).to have_http_status(:ok)
      end

      it "エントリーのスコアを表示すること" do
        get singing_ranking_season_path(season)
        expect(response.body).to include("95")
        expect(response.body).to include("88")
      end

      it "称号を表示すること" do
        get singing_ranking_season_path(season)
        expect(response.body).to include("月間TOPシンガー")
      end

      it "badge_key に応じたバッジを表示すること" do
        get singing_ranking_season_path(season)
        expect(response.body).to include("月間トップシンガー")
        expect(response.body).to include("🏆")
      end

      it "カテゴリラベルを表示すること" do
        get singing_ranking_season_path(season)
        expect(response.body).to include("総合ランキング")
      end

      it "ランク1位・2位のスコアが両方表示されること" do
        get singing_ranking_season_path(season)
        expect(response.body).to include("95")
        expect(response.body).to include("88")
      end
    end

    context "category が複数あるシーズン" do
      let!(:season)   { FactoryBot.create(:singing_ranking_season) }
      let!(:customer1) { FactoryBot.create(:customer, domain_name: "singing") }
      let!(:customer2) { FactoryBot.create(:customer, domain_name: "singing") }

      before do
        CustomerDomain.find_or_create_by!(customer: customer1, domain: singing_domain)
        CustomerDomain.find_or_create_by!(customer: customer2, domain: singing_domain)
        FactoryBot.create(:singing_season_ranking_entry,
                          singing_ranking_season: season, customer: customer1,
                          category: "overall", rank: 1, score: 90)
        FactoryBot.create(:singing_season_ranking_entry,
                          singing_ranking_season: season, customer: customer2,
                          category: "growth", rank: 1, score: 20)
      end

      it "複数カテゴリのラベルを表示すること" do
        get singing_ranking_season_path(season)
        expect(response.body).to include("総合ランキング")
        expect(response.body).to include("成長ランキング")
      end
    end

    context "存在しない ID にアクセスした場合" do
      it "404 または リダイレクトすること" do
        expect {
          get singing_ranking_season_path(id: 9_999_999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
