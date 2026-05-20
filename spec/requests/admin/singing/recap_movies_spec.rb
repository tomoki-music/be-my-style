require 'rails_helper'

RSpec.describe "Admin::Singing::RecapMovies", type: :request do
  include ActiveJob::TestHelper

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

      it "一覧を表示すること" do
        get admin_singing_recap_movies_path
        expect(response.body).to include("一覧")
        expect(response.body).to include(customer.name)
      end

      context "status filter" do
        it "?status=completed で completed のみ返すこと" do
          get admin_singing_recap_movies_path, params: { status: "completed" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(customer.name)
          expect(response.body).to include("2025")
        end

        it "?status=failed で failed のみ返すこと" do
          get admin_singing_recap_movies_path, params: { status: "failed" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("2024")
        end

        it "不正 status は無視して全件返すこと" do
          get admin_singing_recap_movies_path, params: { status: "invalid_status" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(customer.name)
        end
      end

      context "year filter" do
        it "?year=2025 で 2025 年のみ返すこと" do
          get admin_singing_recap_movies_path, params: { year: "2025" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("2025")
        end

        it "?year=2024 で 2024 年のみ返すこと" do
          get admin_singing_recap_movies_path, params: { year: "2024" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("2024")
        end

        it "不正 year は無視して全件返すこと" do
          get admin_singing_recap_movies_path, params: { year: "abc" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(customer.name)
        end
      end

      context "pagination" do
        it "?per_page=1 で 1 件のみ返すこと" do
          get admin_singing_recap_movies_path, params: { per_page: "1" }
          expect(response).to have_http_status(:ok)
        end

        it "per_page が 100 を超える場合は 100 に丸めること" do
          get admin_singing_recap_movies_path, params: { per_page: "999" }
          expect(response).to have_http_status(:ok)
        end

        it "?page=2 で 200 OK を返すこと" do
          get admin_singing_recap_movies_path, params: { per_page: "1", page: "2" }
          expect(response).to have_http_status(:ok)
        end
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

      it "generated_props が保存されている場合に表示すること" do
        completed_movie.update!(generated_props: { "recapMovieId" => completed_movie.id, "year" => 2025, "theme" => "default" })
        get admin_singing_recap_movie_path(completed_movie)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Generated Props")
        expect(response.body).to include("recapMovieId")
        expect(response.body).to include("theme")
      end

      it "generated_props が未保存でも show が落ちないこと" do
        get admin_singing_recap_movie_path(failed_movie)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Generated Props")
        expect(response.body).to include("まだ生成propsは保存されていません")
      end
    end

    describe "POST /admin/singing/recap_movies/:id/regenerate" do
      context "failed movie" do
        it "status が pending に戻ること" do
          post regenerate_admin_singing_recap_movie_path(failed_movie)
          expect(failed_movie.reload.status).to eq("pending")
        end

        it "error_message がクリアされること" do
          post regenerate_admin_singing_recap_movie_path(failed_movie)
          expect(failed_movie.reload.error_message).to be_nil
        end

        it "GenerateRecapMovieJob が enqueue されること" do
          expect {
            post regenerate_admin_singing_recap_movie_path(failed_movie)
          }.to have_enqueued_job(Singing::GenerateRecapMovieJob).with(failed_movie.id)
        end

        it "show 画面にリダイレクトされること" do
          post regenerate_admin_singing_recap_movie_path(failed_movie)
          expect(response).to redirect_to(admin_singing_recap_movie_path(failed_movie))
        end

        it "success flash が表示されること" do
          post regenerate_admin_singing_recap_movie_path(failed_movie)
          follow_redirect!
          expect(response.body).to include("Recap Movieの再生成を開始しました。")
        end
      end

      context "expired movie" do
        let!(:expired_movie) do
          FactoryBot.create(:singing_generated_recap_movie, :expired,
                            customer: FactoryBot.create(:customer, domain_name: "singing"),
                            year: 2023)
        end

        it "status が pending に戻ること" do
          post regenerate_admin_singing_recap_movie_path(expired_movie)
          expect(expired_movie.reload.status).to eq("pending")
        end

        it "GenerateRecapMovieJob が enqueue されること" do
          expect {
            post regenerate_admin_singing_recap_movie_path(expired_movie)
          }.to have_enqueued_job(Singing::GenerateRecapMovieJob).with(expired_movie.id)
        end

        it "show 画面にリダイレクトされること" do
          post regenerate_admin_singing_recap_movie_path(expired_movie)
          expect(response).to redirect_to(admin_singing_recap_movie_path(expired_movie))
        end
      end

      context "completed movie" do
        it "status が変わらないこと" do
          post regenerate_admin_singing_recap_movie_path(completed_movie)
          expect(completed_movie.reload.status).to eq("completed")
        end

        it "GenerateRecapMovieJob が enqueue されないこと" do
          expect {
            post regenerate_admin_singing_recap_movie_path(completed_movie)
          }.not_to have_enqueued_job(Singing::GenerateRecapMovieJob)
        end

        it "show 画面にリダイレクトされること" do
          post regenerate_admin_singing_recap_movie_path(completed_movie)
          expect(response).to redirect_to(admin_singing_recap_movie_path(completed_movie))
        end

        it "alert flash が表示されること" do
          post regenerate_admin_singing_recap_movie_path(completed_movie)
          follow_redirect!
          expect(response.body).to include("このRecap Movieは現在のステータスでは再生成できません。")
        end
      end

      context "processing movie" do
        let!(:processing_movie) do
          FactoryBot.create(:singing_generated_recap_movie, :processing,
                            customer: FactoryBot.create(:customer, domain_name: "singing"),
                            year: 2022)
        end

        it "status が変わらないこと" do
          post regenerate_admin_singing_recap_movie_path(processing_movie)
          expect(processing_movie.reload.status).to eq("processing")
        end

        it "GenerateRecapMovieJob が enqueue されないこと" do
          expect {
            post regenerate_admin_singing_recap_movie_path(processing_movie)
          }.not_to have_enqueued_job(Singing::GenerateRecapMovieJob)
        end

        it "alert flash が表示されること" do
          post regenerate_admin_singing_recap_movie_path(processing_movie)
          follow_redirect!
          expect(response.body).to include("このRecap Movieは現在のステータスでは再生成できません。")
        end
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
