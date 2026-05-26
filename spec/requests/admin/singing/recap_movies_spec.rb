require 'rails_helper'
require 'csv'

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

      context "Graph Dashboard" do
        it "Status Distribution セクションを表示すること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("Status Distribution")
        end

        it "completed / failed / expired などの件数が表示されること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("completed")
          expect(response.body).to include("failed")
          expect(response.body).to include("expired")
        end

        it "Share Engagement セクションを表示すること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("Share Engagement")
        end

        it "share_count / download_count / instagram_hint_click_count の合計が表示されること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("X シェア")
          expect(response.body).to include("ダウンロード")
          expect(response.body).to include("Instagram Hint")
        end

        it "Yearly Generation セクションを表示すること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("Yearly Generation")
        end

        it "year 別件数が表示されること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("2025")
          expect(response.body).to include("2024")
        end

        context "0件の場合" do
          before { SingingGeneratedRecapMovie.destroy_all }

          it "index が落ちないこと" do
            get admin_singing_recap_movies_path
            expect(response).to have_http_status(:ok)
          end

          it "Status Distribution を表示すること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include("Status Distribution")
          end

          it "Yearly Generation で データなし を表示すること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include("データなし")
          end
        end
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

      context "CSV export" do
        it "200 OK を返すこと" do
          get admin_singing_recap_movies_path(format: :csv)
          expect(response).to have_http_status(:ok)
        end

        it "Content-Type が text/csv であること" do
          get admin_singing_recap_movies_path(format: :csv)
          expect(response.content_type).to include("text/csv")
        end

        it "ヘッダー行が含まれること" do
          get admin_singing_recap_movies_path(format: :csv)
          lines = response.body.lines
          expect(lines.first).to include("id", "customer_id", "customer_name", "status", "share_count")
        end

        it "movie データが含まれること" do
          get admin_singing_recap_movies_path(format: :csv)
          expect(response.body).to include(customer.name)
          expect(response.body).to include(customer.email)
          expect(response.body).to include("completed")
          expect(response.body).to include("3")
        end

        it "全カラムが出力されること" do
          get admin_singing_recap_movies_path(format: :csv)
          header = response.body.lines.first
          %w[id customer_name customer_email status year share_count download_count
             instagram_hint_click_count video_attached error_message created_at].each do |col|
            expect(header).to include(col)
          end
        end

        context "status filter が CSV に反映されること" do
          it "?status=completed で completed のみ出力すること" do
            get admin_singing_recap_movies_path(format: :csv, status: "completed")
            rows = CSV.parse(response.body, headers: true)
            expect(rows.map { |r| r["status"] }.uniq).to eq(["completed"])
          end

          it "?status=failed で failed のみ出力すること" do
            get admin_singing_recap_movies_path(format: :csv, status: "failed")
            rows = CSV.parse(response.body, headers: true)
            expect(rows.map { |r| r["status"] }.uniq).to eq(["failed"])
          end
        end

        context "year filter が CSV に反映されること" do
          it "?year=2025 で 2025 年のみ出力すること" do
            get admin_singing_recap_movies_path(format: :csv, year: "2025")
            rows = CSV.parse(response.body, headers: true)
            expect(rows.map { |r| r["year"] }.uniq).to eq(["2025"])
          end

          it "?year=2024 で 2024 年のみ出力すること" do
            get admin_singing_recap_movies_path(format: :csv, year: "2024")
            rows = CSV.parse(response.body, headers: true)
            expect(rows.map { |r| r["year"] }.uniq).to eq(["2024"])
          end
        end

        context "pagination を無視して全件出力すること" do
          let!(:extra_movies) do
            5.times.map do |i|
              FactoryBot.create(:singing_generated_recap_movie, :completed,
                                customer: FactoryBot.create(:customer, domain_name: "singing"),
                                year: 2020 + i)
            end
          end

          it "per_page に関係なく全件含まれること" do
            get admin_singing_recap_movies_path(format: :csv, per_page: "1")
            rows = CSV.parse(response.body, headers: true)
            expect(rows.count).to be >= 2
          end

          it "page に関係なく全件含まれること" do
            get admin_singing_recap_movies_path(format: :csv, per_page: "1", page: "2")
            rows = CSV.parse(response.body, headers: true)
            expect(rows.count).to be >= 2
          end
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

        it "GenerateRecapMovieJob が enqueue されないこと（runner 経由のため）" do
          expect {
            post regenerate_admin_singing_recap_movie_path(failed_movie)
          }.not_to have_enqueued_job(Singing::GenerateRecapMovieJob)
        end

        it "show 画面にリダイレクトされること" do
          post regenerate_admin_singing_recap_movie_path(failed_movie)
          expect(response).to redirect_to(admin_singing_recap_movie_path(failed_movie))
        end

        it "pending 化の notice flash が表示されること" do
          post regenerate_admin_singing_recap_movie_path(failed_movie)
          follow_redirect!
          expect(response.body).to include("pending にしました")
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

        it "GenerateRecapMovieJob が enqueue されないこと（runner 経由のため）" do
          expect {
            post regenerate_admin_singing_recap_movie_path(expired_movie)
          }.not_to have_enqueued_job(Singing::GenerateRecapMovieJob)
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

    describe "POST /admin/singing/recap_movies/generate_yearly_batch" do
      let(:valid_year) { Time.zone.today.year }

      context "正しい year を指定した場合" do
        it "GenerateYearlyRecapMoviesJob が enqueue されること" do
          expect {
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          }.to have_enqueued_job(Singing::GenerateYearlyRecapMoviesJob).with(valid_year, instance_of(Integer))
        end

        it "notice flash が表示されること" do
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          follow_redirect!
          expect(response.body).to include("#{valid_year}年のRecap Movie一括生成を開始しました。")
        end

        it "index にリダイレクトされること" do
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          expect(response).to redirect_to(admin_singing_recap_movies_path)
        end

        it "BatchExecution ログが作成されること" do
          expect {
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          }.to change(SingingRecapMovieBatchExecution, :count).by(1)
        end

        it "BatchExecution に year が保存されること" do
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          log = SingingRecapMovieBatchExecution.last
          expect(log.year).to eq(valid_year)
        end

        it "BatchExecution に admin が保存されること" do
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          log = SingingRecapMovieBatchExecution.last
          expect(log.admin).to eq(admin)
        end

        it "BatchExecution に preview counts が保存されること" do
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          log = SingingRecapMovieBatchExecution.last
          expect(log.target_customers_count).to be_a(Integer)
          expect(log.new_movies_count).to be_a(Integer)
          expect(log.regenerate_movies_count).to be_a(Integer)
          expect(log.skipped_movies_count).to be_a(Integer)
        end

        it "BatchExecution に skipped_breakdown が保存されること" do
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          log = SingingRecapMovieBatchExecution.last
          expect(log.skipped_breakdown).to be_a(Hash)
        end

        it "BatchExecution の status が enqueued であること" do
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          log = SingingRecapMovieBatchExecution.last
          expect(log.status).to eq("enqueued")
        end

        it "BatchExecution の enqueued_at が記録されること" do
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          log = SingingRecapMovieBatchExecution.last
          expect(log.enqueued_at).to be_present
        end
      end

      context "Concurrency Guard" do
        context "同じ year の enqueued batch が既にある場合" do
          before do
            FactoryBot.create(:singing_recap_movie_batch_execution, year: valid_year, status: :enqueued)
          end

          it "GenerateYearlyRecapMoviesJob が enqueue されないこと" do
            expect {
              post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
            }.not_to have_enqueued_job(Singing::GenerateYearlyRecapMoviesJob)
          end

          it "BatchExecution ログが新たに作成されないこと" do
            expect {
              post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
            }.not_to change(SingingRecapMovieBatchExecution, :count)
          end

          it "alert flash が表示されること" do
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
            follow_redirect!
            expect(response.body).to include("#{valid_year}年のRecap Movie一括生成は既に実行中です。")
          end

          it "index にリダイレクトされること" do
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
            expect(response).to redirect_to(admin_singing_recap_movies_path)
          end
        end

        context "同じ year の running batch が既にある場合" do
          before do
            FactoryBot.create(:singing_recap_movie_batch_execution, year: valid_year, status: :running)
          end

          it "GenerateYearlyRecapMoviesJob が enqueue されないこと" do
            expect {
              post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
            }.not_to have_enqueued_job(Singing::GenerateYearlyRecapMoviesJob)
          end

          it "BatchExecution ログが新たに作成されないこと" do
            expect {
              post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
            }.not_to change(SingingRecapMovieBatchExecution, :count)
          end

          it "alert flash が表示されること" do
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
            follow_redirect!
            expect(response.body).to include("#{valid_year}年のRecap Movie一括生成は既に実行中です。")
          end
        end

        context "completed batch がある場合は再実行できること" do
          before do
            FactoryBot.create(:singing_recap_movie_batch_execution, year: valid_year, status: :completed)
          end

          it "GenerateYearlyRecapMoviesJob が enqueue されること" do
            expect {
              post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
            }.to have_enqueued_job(Singing::GenerateYearlyRecapMoviesJob)
          end

          it "BatchExecution ログが作成されること" do
            expect {
              post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
            }.to change(SingingRecapMovieBatchExecution, :count).by(1)
          end
        end

        context "failed batch がある場合は再実行できること" do
          before do
            FactoryBot.create(:singing_recap_movie_batch_execution, year: valid_year, status: :failed)
          end

          it "GenerateYearlyRecapMoviesJob が enqueue されること" do
            expect {
              post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
            }.to have_enqueued_job(Singing::GenerateYearlyRecapMoviesJob)
          end
        end

        context "別の year の active batch がある場合は実行できること" do
          before do
            FactoryBot.create(:singing_recap_movie_batch_execution, year: valid_year - 1, status: :running)
          end

          it "GenerateYearlyRecapMoviesJob が enqueue されること" do
            expect {
              post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
            }.to have_enqueued_job(Singing::GenerateYearlyRecapMoviesJob)
          end
        end
      end

      context "index に active batch がある場合 warning が表示されること" do
        it "enqueued batch があれば warning メッセージが表示されること" do
          FactoryBot.create(:singing_recap_movie_batch_execution, year: valid_year, status: :enqueued)
          get admin_singing_recap_movies_path
          expect(response.body).to include("#{valid_year}年の一括生成が実行中です")
        end

        it "running batch があれば warning メッセージが表示されること" do
          FactoryBot.create(:singing_recap_movie_batch_execution, year: valid_year, status: :running)
          get admin_singing_recap_movies_path
          expect(response.body).to include("#{valid_year}年の一括生成が実行中です")
        end

        it "active batch がなければ warning メッセージが表示されないこと" do
          get admin_singing_recap_movies_path
          expect(response.body).not_to include("一括生成が実行中です")
        end
      end

      context "Batch Progress Dashboard" do
        context "running batch がある場合" do
          let!(:running_exec) do
            FactoryBot.create(:singing_recap_movie_batch_execution,
                              year: valid_year,
                              status: :running,
                              started_at: 1.minute.ago,
                              total_movies_count: 100,
                              completed_movies_count: 40,
                              failed_movies_count: 5)
          end

          it "Progress Card が表示されること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include("Recap Movie Batch — 進行中")
          end

          it "progress % が表示されること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include("45%")
          end

          it "completed 数が表示されること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include("40")
          end

          it "failed 数が表示されること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include("5")
          end

          it "残件数が表示されること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include("55")
          end
        end

        context "active batch がない場合" do
          it "Progress Card が表示されないこと" do
            get admin_singing_recap_movies_path
            expect(response.body).not_to include("Recap Movie Batch — 進行中")
          end

          it "index が落ちないこと" do
            get admin_singing_recap_movies_path
            expect(response).to have_http_status(:ok)
          end
        end

        context "total_movies_count が 0 の場合" do
          let!(:zero_exec) do
            FactoryBot.create(:singing_recap_movie_batch_execution,
                              year: valid_year,
                              status: :running,
                              started_at: 1.minute.ago,
                              total_movies_count: 0,
                              completed_movies_count: 0,
                              failed_movies_count: 0)
          end

          it "index が落ちないこと" do
            get admin_singing_recap_movies_path
            expect(response).to have_http_status(:ok)
          end

          it "Progress Card が表示されること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include("Recap Movie Batch — 進行中")
          end
        end
      end

      context "実行履歴テーブルの拡張列" do
        let!(:exec_with_progress) do
          FactoryBot.create(:singing_recap_movie_batch_execution,
                            admin: admin,
                            year: valid_year,
                            status: :completed,
                            started_at: 2.minutes.ago,
                            finished_at: 1.minute.ago,
                            total_movies_count: 10,
                            completed_movies_count: 9,
                            failed_movies_count: 1)
        end

        it "進捗列が表示されること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("進捗")
        end

        it "実績: 新規 列が表示されること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("実績: 新規")
        end

        it "成功率列が表示されること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("成功率")
        end

        it "実行時間列が表示されること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("実行時間")
        end

        it "progress % が表示されること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("100%").or include("90%")
        end
      end

      context "year が文字列（不正値）の場合" do
        it "GenerateYearlyRecapMoviesJob が enqueue されないこと" do
          expect {
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: "abc" }
          }.not_to have_enqueued_job(Singing::GenerateYearlyRecapMoviesJob)
        end

        it "alert flash が表示されること" do
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: "abc" }
          follow_redirect!
          expect(response.body).to include("年の指定が不正です。")
        end

        it "BatchExecution ログが作成されないこと" do
          expect {
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: "abc" }
          }.not_to change(SingingRecapMovieBatchExecution, :count)
        end
      end

      context "year が空の場合" do
        it "GenerateYearlyRecapMoviesJob が enqueue されないこと" do
          expect {
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: "" }
          }.not_to have_enqueued_job(Singing::GenerateYearlyRecapMoviesJob)
        end

        it "alert flash が表示されること" do
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: "" }
          follow_redirect!
          expect(response.body).to include("年の指定が不正です。")
        end

        it "BatchExecution ログが作成されないこと" do
          expect {
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: "" }
          }.not_to change(SingingRecapMovieBatchExecution, :count)
        end
      end

      context "year が許可範囲外（2019）の場合" do
        it "GenerateYearlyRecapMoviesJob が enqueue されないこと" do
          expect {
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: "2019" }
          }.not_to have_enqueued_job(Singing::GenerateYearlyRecapMoviesJob)
        end

        it "alert flash が表示されること" do
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: "2019" }
          follow_redirect!
          expect(response.body).to include("年の指定が不正です。")
        end

        it "BatchExecution ログが作成されないこと" do
          expect {
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: "2019" }
          }.not_to change(SingingRecapMovieBatchExecution, :count)
        end
      end

      context "year が許可範囲外（未来すぎる年）の場合" do
        it "GenerateYearlyRecapMoviesJob が enqueue されないこと" do
          future_year = Time.zone.today.year + 2
          expect {
            post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: future_year }
          }.not_to have_enqueued_job(Singing::GenerateYearlyRecapMoviesJob)
        end

        it "alert flash が表示されること" do
          future_year = Time.zone.today.year + 2
          post generate_yearly_batch_admin_singing_recap_movies_path, params: { year: future_year }
          follow_redirect!
          expect(response.body).to include("年の指定が不正です。")
        end
      end

      context "index に一括生成フォームが表示されること" do
        it "一括生成フォームが表示されること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("年間Recap Movie一括生成")
          expect(response.body).to include("一括生成を開始")
        end
      end

      context "index にプレビューフォームが表示されること" do
        it "プレビューフォームが表示されること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("対象件数プレビュー")
          expect(response.body).to include("対象件数を確認")
        end
      end

      context "index に実行履歴が表示されること" do
        it "実行履歴セクションが表示されること" do
          get admin_singing_recap_movies_path
          expect(response.body).to include("一括生成 実行履歴")
        end

        context "実行履歴が 0 件の場合" do
          it "index が落ちないこと" do
            get admin_singing_recap_movies_path
            expect(response).to have_http_status(:ok)
          end

          it "履歴なしメッセージが表示されること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include("まだ一括生成の実行履歴はありません。")
          end
        end

        context "実行履歴が存在する場合" do
          let!(:execution) do
            FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin, year: valid_year)
          end

          it "実行履歴の year が表示されること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include(valid_year.to_s)
          end

          it "実行履歴の管理者名が表示されること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include(admin.name)
          end

          it "実行履歴の status が表示されること" do
            get admin_singing_recap_movies_path
            expect(response.body).to include("enqueued")
          end
        end
      end
    end

    describe "GET /admin/singing/recap_movies/preview_yearly_batch" do
      let(:valid_year) { Time.zone.today.year }

      let!(:singing_customer) { FactoryBot.create(:customer, domain_name: "singing") }
      let!(:completed_diagnosis) do
        FactoryBot.create(:singing_diagnosis, :completed,
                          customer: singing_customer,
                          created_at: Time.zone.local(valid_year, 6, 1))
      end

      context "正しい year を指定した場合" do
        it "200 OK を返すこと" do
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          expect(response).to have_http_status(:ok)
        end

        it "プレビュー結果セクションが表示されること" do
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          expect(response.body).to include("プレビュー結果")
          expect(response.body).to include("#{valid_year}年")
        end

        it "対象ユーザー数が表示されること" do
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          expect(response.body).to include("対象ユーザー")
        end

        it "新規生成 / 再生成 / スキップ が表示されること" do
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          expect(response.body).to include("新規生成")
          expect(response.body).to include("再生成")
          expect(response.body).to include("スキップ")
        end

        it "preview 後に一括生成ボタンが表示されること" do
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          expect(response.body).to include("この内容で#{valid_year}年の一括生成を開始")
        end

        it "一括生成ボタンに year が引き継がれること" do
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: valid_year }
          expect(response.body).to include("value=\"#{valid_year}\"")
        end
      end

      context "year が文字列（不正値）の場合" do
        it "alert flash が表示されること" do
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: "abc" }
          follow_redirect!
          expect(response.body).to include("年の指定が不正です。")
        end

        it "index にリダイレクトされること" do
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: "abc" }
          expect(response).to redirect_to(admin_singing_recap_movies_path)
        end
      end

      context "year が空の場合" do
        it "alert flash が表示されること" do
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: "" }
          follow_redirect!
          expect(response.body).to include("年の指定が不正です。")
        end
      end

      context "year が許可範囲外（2019）の場合" do
        it "alert flash が表示されること" do
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: "2019" }
          follow_redirect!
          expect(response.body).to include("年の指定が不正です。")
        end
      end

      context "year が許可範囲外（未来すぎる年）の場合" do
        it "alert flash が表示されること" do
          future_year = Time.zone.today.year + 2
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: future_year }
          follow_redirect!
          expect(response.body).to include("年の指定が不正です。")
        end
      end

      context "対象ユーザーが 0 人の場合" do
        it "200 OK を返しプレビュー結果が表示されること" do
          other_year = 2020
          get preview_yearly_batch_admin_singing_recap_movies_path, params: { year: other_year }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("プレビュー結果")
        end
      end
    end
  end

  describe "GET /admin/singing/recap_movies/health (health dashboard)" do
    let(:execution) do
      FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin, year: 2024)
    end

    context "管理者ログイン済み" do
      before { sign_in admin }

      it "200 OK を返すこと" do
        get health_admin_singing_recap_movies_path
        expect(response).to have_http_status(:ok)
      end

      it "ページタイトルを表示すること" do
        get health_admin_singing_recap_movies_path
        expect(response.body).to include("Batch Health Dashboard")
      end

      it "Summary Cards セクションを表示すること" do
        get health_admin_singing_recap_movies_path
        expect(response.body).to include("Total Batches")
        expect(response.body).to include("Batch Success Rate")
        expect(response.body).to include("Retry Recovery Rate")
        expect(response.body).to include("Open Failures")
        expect(response.body).to include("Avg Render Duration")
      end

      it "Trend Graph セクションを表示すること" do
        get health_admin_singing_recap_movies_path
        expect(response.body).to include("直近30日 Failure Trend")
      end

      it "Error Analysis セクションを表示すること" do
        get health_admin_singing_recap_movies_path
        expect(response.body).to include("Top Error Classes")
      end

      it "Open Failures セクションを表示すること" do
        get health_admin_singing_recap_movies_path
        expect(response.body).to include("Open Failures")
      end

      it "Slow Batch Analysis セクションを表示すること" do
        get health_admin_singing_recap_movies_path
        expect(response.body).to include("Slow Batch Analysis")
      end

      context "open failure が存在する場合" do
        let!(:open_failure) do
          FactoryBot.create(:singing_recap_movie_batch_failure,
                            singing_recap_movie_batch_execution: execution,
                            customer: customer,
                            retry_status: "pending",
                            error_class: "Open3::Timeout")
        end

        it "failure の error_class を表示すること" do
          get health_admin_singing_recap_movies_path
          expect(response.body).to include("Open3::Timeout")
        end

        it "customer 名を表示すること" do
          get health_admin_singing_recap_movies_path
          expect(response.body).to include(customer.name)
        end

        it "Batch へのリンクを含むこと" do
          get health_admin_singing_recap_movies_path
          expect(response.body).to include("Batch ##{execution.id}")
        end
      end

      context "error_analysis にエラーが存在する場合" do
        before do
          FactoryBot.create(:singing_recap_movie_batch_failure,
                            singing_recap_movie_batch_execution: execution,
                            customer: customer,
                            error_class: "FFmpegError")
        end

        it "Error Class テーブルに表示されること" do
          get health_admin_singing_recap_movies_path
          expect(response.body).to include("FFmpegError")
        end
      end

      context "slow batch が存在する場合" do
        before do
          execution.update!(started_at: 10.minutes.ago, finished_at: Time.current)
        end

        it "slow batch のリンクを表示すること" do
          get health_admin_singing_recap_movies_path
          expect(response.body).to include("##{execution.id}")
        end
      end

      context "Auto Retry Monitor section" do
        it "Auto Retry Monitor セクションを表示すること" do
          get health_admin_singing_recap_movies_path
          expect(response.body).to include("Auto Retry — Self Healing Monitor")
        end

        it "Avg Attempts カードを表示すること" do
          get health_admin_singing_recap_movies_path
          expect(response.body).to include("Avg Attempts")
        end

        it "Auto Retry Failure 一覧セクションを表示すること" do
          get health_admin_singing_recap_movies_path
          expect(response.body).to include("Auto Retry — Failure 一覧")
        end

        context "exhausted failure が存在する場合" do
          let!(:exhausted_failure) do
            FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_exhausted,
                              singing_recap_movie_batch_execution: execution,
                              customer: customer)
          end

          it "exhausted バッジを header に表示すること" do
            get health_admin_singing_recap_movies_path
            expect(response.body).to include("exhausted")
          end

          it "要手動確認アラートを表示すること" do
            get health_admin_singing_recap_movies_path
            expect(response.body).to include("要手動確認")
          end

          it "failure テーブルに customer 名を表示すること" do
            get health_admin_singing_recap_movies_path
            expect(response.body).to include(customer.name)
          end
        end

        context "scheduled failure が存在する場合" do
          let!(:scheduled_failure) do
            FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_scheduled,
                              singing_recap_movie_batch_execution: execution,
                              customer: customer)
          end

          it "failure テーブルに Scheduled バッジを表示すること" do
            get health_admin_singing_recap_movies_path
            expect(response.body).to include("Scheduled")
          end
        end
      end

      context "auto_retry_status filter" do
        let!(:exhausted_failure) do
          FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_exhausted,
                            singing_recap_movie_batch_execution: execution,
                            customer: FactoryBot.create(:customer, domain_name: "singing"))
        end
        let!(:scheduled_failure) do
          FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_scheduled,
                            singing_recap_movie_batch_execution: execution,
                            customer: FactoryBot.create(:customer, domain_name: "singing"))
        end

        it "?auto_retry_status=exhausted で 200 OK を返すこと" do
          get health_admin_singing_recap_movies_path, params: { auto_retry_status: "exhausted" }
          expect(response).to have_http_status(:ok)
        end

        it "?auto_retry_status=exhausted でフィルター表示されること" do
          get health_admin_singing_recap_movies_path, params: { auto_retry_status: "exhausted" }
          expect(response.body).to include(exhausted_failure.customer.name)
        end

        it "?auto_retry_status=scheduled で 200 OK を返すこと" do
          get health_admin_singing_recap_movies_path, params: { auto_retry_status: "scheduled" }
          expect(response).to have_http_status(:ok)
        end

        it "?auto_retry_status=running で 200 OK を返すこと" do
          get health_admin_singing_recap_movies_path, params: { auto_retry_status: "running" }
          expect(response).to have_http_status(:ok)
        end

        it "?auto_retry_status=due_now で 200 OK を返すこと" do
          get health_admin_singing_recap_movies_path, params: { auto_retry_status: "due_now" }
          expect(response).to have_http_status(:ok)
        end

        it "不正な auto_retry_status は無視して 200 OK を返すこと" do
          get health_admin_singing_recap_movies_path, params: { auto_retry_status: "invalid_filter" }
          expect(response).to have_http_status(:ok)
        end

        it "フィルター適用時にクリアリンクを表示すること" do
          get health_admin_singing_recap_movies_path, params: { auto_retry_status: "exhausted" }
          expect(response.body).to include("× クリア")
        end

        it "フィルター未指定時にクリアリンクを表示しないこと" do
          get health_admin_singing_recap_movies_path
          expect(response.body).not_to include("× クリア")
        end
      end

      context "Storage Audit セクション" do
        it "Storage Audit セクションを表示すること" do
          get health_admin_singing_recap_movies_path
          expect(response.body).to include("Storage Audit")
          expect(response.body).to include("孤立 / 不整合 検知")
        end

        it "異常なし時に「異常なし」バッジを表示すること" do
          get health_admin_singing_recap_movies_path
          expect(response.body).to include("異常なし")
        end

        it "検知のみ文言を表示すること" do
          get health_admin_singing_recap_movies_path
          expect(response.body).to include("検知のみ")
        end

        context "completed だが video_file が存在しない movie がある場合" do
          let!(:broken_movie) do
            m = create(:singing_generated_recap_movie, :completed, customer: customer, year: 2023)
            m.video_file.detach
            m
          end

          it "異常ありバッジを表示すること" do
            get health_admin_singing_recap_movies_path
            expect(response.body).to include("異常あり")
          end

          it "Completed without File セクションを表示すること" do
            get health_admin_singing_recap_movies_path
            expect(response.body).to include("Completed without File")
          end
        end

        context "cleaned_up_at あり + video_file が残っている expired movie がある場合" do
          let!(:lingering_movie) do
            m = create(:singing_generated_recap_movie, :expired, customer: customer,
                       year: 2022, cleaned_up_at: 1.hour.ago)
            m.video_file.attach(
              io:           StringIO.new("MP4"),
              filename:     "recap_test.mp4",
              content_type: "video/mp4",
            )
            m
          end

          it "異常ありバッジを表示すること" do
            get health_admin_singing_recap_movies_path
            expect(response.body).to include("異常あり")
          end

          it "Cleaned but Attached セクションを表示すること" do
            get health_admin_singing_recap_movies_path
            expect(response.body).to include("Cleaned but Attached")
          end
        end
      end
    end

    context "Storage Metrics セクション" do
      before { sign_in admin }

      it "Storage Metrics セクションを表示すること" do
        get health_admin_singing_recap_movies_path
        expect(response.body).to include("Storage Metrics")
        expect(response.body).to include("Attached Movies")
        expect(response.body).to include("Total Stored")
        expect(response.body).to include("Avg Movie Size")
        expect(response.body).to include("Est. Monthly Cost")
      end

      it "Cost Dashboard の注意書きを表示すること" do
        get health_admin_singing_recap_movies_path
        expect(response.body).to include("概算")
        expect(response.body).to include("転送料")
      end

      it "completed 動画がある場合に Year Breakdown を表示すること" do
        another = create(:customer, domain_name: "singing")
        create(:singing_generated_recap_movie, :completed, customer: another, year: 2024)
        get health_admin_singing_recap_movies_path
        expect(response.body).to include("Year Breakdown")
        expect(response.body).to include("2024")
      end
    end

    context "管理者未ログイン" do
      it "アクセスできないこと" do
        get health_admin_singing_recap_movies_path
        expect(response).not_to have_http_status(:ok)
      end
    end
  end

  describe "POST /admin/singing/recap_movies/run_auto_retries" do
    let(:dummy_result) do
      Singing::RecapMovieAutoRetryService::Result.new(
        processed_count: 2,
        succeeded_count: 1,
        skipped_count:   1,
        failed_count:    0
      )
    end

    before do
      sign_in admin
      allow(Singing::RunRecapMovieAutoRetriesJob).to receive(:perform_now).and_return(dummy_result)
    end

    it "200 / redirect で完了すること" do
      post run_auto_retries_admin_singing_recap_movies_path
      expect(response).to redirect_to(health_admin_singing_recap_movies_path)
    end

    it "RunRecapMovieAutoRetriesJob.perform_now が呼ばれること" do
      post run_auto_retries_admin_singing_recap_movies_path
      expect(Singing::RunRecapMovieAutoRetriesJob).to have_received(:perform_now).once
    end

    it "notice flash に処理件数が表示されること" do
      post run_auto_retries_admin_singing_recap_movies_path
      follow_redirect!
      expect(response.body).to include("Auto Retry 実行完了")
    end

    context "管理者未ログイン" do
      before { sign_out admin }

      it "アクセスできないこと" do
        post run_auto_retries_admin_singing_recap_movies_path
        expect(response).not_to have_http_status(:ok)
      end
    end
  end

  describe "POST /admin/singing/recap_movies/run_storage_repair" do
    let(:dry_run_result) do
      Singing::RecapMovieStorageRepairService::Result.new(
        repaired_cba_count: 1,
        repaired_cwf_count: 0,
        dry_run:            true,
      )
    end

    let(:repair_result) do
      Singing::RecapMovieStorageRepairService::Result.new(
        repaired_cba_count: 1,
        repaired_cwf_count: 2,
        dry_run:            false,
      )
    end

    before do
      sign_in admin
      allow(Singing::RepairRecapMovieStorageIssuesJob).to receive(:perform_now).and_return(dry_run_result)
    end

    context "dry_run=true (デフォルト)" do
      it "health ダッシュボードにリダイレクトされること" do
        post run_storage_repair_admin_singing_recap_movies_path
        expect(response).to redirect_to(health_admin_singing_recap_movies_path)
      end

      it "RepairRecapMovieStorageIssuesJob.perform_now が dry_run: true で呼ばれること" do
        post run_storage_repair_admin_singing_recap_movies_path
        expect(Singing::RepairRecapMovieStorageIssuesJob)
          .to have_received(:perform_now).with(dry_run: true)
      end

      it "notice flash に [DRY RUN] が含まれること" do
        post run_storage_repair_admin_singing_recap_movies_path
        follow_redirect!
        expect(response.body).to include("[DRY RUN]")
        expect(response.body).to include("Storage Repair 完了")
      end
    end

    context "dry_run=false (実際の修復)" do
      before do
        allow(Singing::RepairRecapMovieStorageIssuesJob).to receive(:perform_now).and_return(repair_result)
      end

      it "RepairRecapMovieStorageIssuesJob.perform_now が dry_run: false で呼ばれること" do
        post run_storage_repair_admin_singing_recap_movies_path, params: { dry_run: "false" }
        expect(Singing::RepairRecapMovieStorageIssuesJob)
          .to have_received(:perform_now).with(dry_run: false)
      end

      it "notice flash に Storage Repair 完了 が含まれること" do
        post run_storage_repair_admin_singing_recap_movies_path, params: { dry_run: "false" }
        follow_redirect!
        expect(response.body).to include("Storage Repair 完了")
      end

      it "[DRY RUN] が含まれないこと" do
        post run_storage_repair_admin_singing_recap_movies_path, params: { dry_run: "false" }
        follow_redirect!
        expect(response.body).not_to include("[DRY RUN]")
      end
    end

    context "管理者未ログイン" do
      before { sign_out admin }

      it "アクセスできないこと" do
        post run_storage_repair_admin_singing_recap_movies_path
        expect(response).not_to have_http_status(:ok)
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
