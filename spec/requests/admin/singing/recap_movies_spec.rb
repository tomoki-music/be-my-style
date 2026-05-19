require 'rails_helper'

RSpec.describe "Admin::Singing::RecapMovies", type: :request do
  let(:admin)    { FactoryBot.create(:admin) }
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }

  let!(:completed_movie) do
    FactoryBot.create(:singing_generated_recap_movie, :completed,
                      customer: customer, year: 2025,
                      share_count: 3, download_count: 2, instagram_hint_click_count: 1)
  end
  let!(:failed_movie) do
    FactoryBot.create(:singing_generated_recap_movie, :failed,
                      customer: customer, year: 2024)
  end

  describe "管理者ログイン済み" do
    before { sign_in admin }

    describe "GET /admin/singing/recap_movies (index)" do
      it "200 OK を返すこと" do
        get admin_singing_recap_movies_path
        expect(response).to have_http_status(:ok)
      end

      it "status 別件数を表示すること" do
        get admin_singing_recap_movies_path
        expect(response.body).to include("completed")
        expect(response.body).to include("failed")
      end

      it "tracking 数値の合計を表示すること" do
        get admin_singing_recap_movies_path
        expect(response.body).to include("3")
        expect(response.body).to include("2")
        expect(response.body).to include("1")
      end

      it "failed movie 一覧を表示すること" do
        get admin_singing_recap_movies_path
        expect(response.body).to include("Failed 一覧")
        expect(response.body).to include("Remotion render failed")
      end

      it "直近生成一覧を表示すること" do
        get admin_singing_recap_movies_path
        expect(response.body).to include("直近生成一覧")
        expect(response.body).to include(customer.name)
      end
    end

    describe "GET /admin/singing/recap_movies/:id (show)" do
      it "completed movie の詳細を 200 で返すこと" do
        get admin_singing_recap_movie_path(completed_movie)
        expect(response).to have_http_status(:ok)
      end

      it "customer 情報を表示すること" do
        get admin_singing_recap_movie_path(completed_movie)
        expect(response.body).to include(customer.name)
        expect(response.body).to include(customer.email)
      end

      it "ステータスを表示すること" do
        get admin_singing_recap_movie_path(completed_movie)
        expect(response.body).to include("completed")
      end

      it "tracking 数値を表示すること" do
        get admin_singing_recap_movie_path(completed_movie)
        expect(response.body).to include("シェア数")
        expect(response.body).to include("ダウンロード数")
        expect(response.body).to include("Instagram導線クリック数")
      end

      it "動画ファイル添付の有無を表示すること" do
        get admin_singing_recap_movie_path(completed_movie)
        expect(response.body).to include("動画ファイル")
        expect(response.body).to include("添付あり")
      end

      it "failed movie の error_message を表示すること" do
        get admin_singing_recap_movie_path(failed_movie)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Remotion render failed")
      end
    end
  end

  describe "非管理者のアクセス" do
    shared_examples "管理者画面にアクセスできない" do
      it "index にアクセスできないこと" do
        get admin_singing_recap_movies_path
        expect(response).not_to have_http_status(:ok)
      end

      it "show にアクセスできないこと" do
        get admin_singing_recap_movie_path(completed_movie)
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
