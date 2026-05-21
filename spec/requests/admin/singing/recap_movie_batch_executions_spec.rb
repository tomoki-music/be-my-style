require "rails_helper"

RSpec.describe "Admin::Singing::RecapMovieBatchExecutions", type: :request do
  let(:admin)    { FactoryBot.create(:admin) }
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }

  let!(:execution) do
    FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin)
  end

  describe "管理者ログイン済み" do
    before { sign_in admin }

    describe "GET /admin/singing/recap_movie_batch_executions/:id (show)" do
      it "200 OK を返すこと" do
        get admin_singing_recap_movie_batch_execution_path(execution)
        expect(response).to have_http_status(:ok)
      end

      it "基本情報（年・ステータス）が表示されること" do
        get admin_singing_recap_movie_batch_execution_path(execution)
        expect(response.body).to include(execution.year.to_s)
        expect(response.body).to include("completed")
      end

      it "管理者名が表示されること" do
        get admin_singing_recap_movie_batch_execution_path(execution)
        expect(response.body).to include(admin.name)
      end

      it "進捗サマリーが表示されること" do
        get admin_singing_recap_movie_batch_execution_path(execution)
        expect(response.body).to include("進捗サマリー")
      end

      it "実績サマリーが表示されること" do
        get admin_singing_recap_movie_batch_execution_path(execution)
        expect(response.body).to include("実績サマリー")
      end

      it "プレビューサマリーが表示されること" do
        get admin_singing_recap_movie_batch_execution_path(execution)
        expect(response.body).to include("プレビューサマリー")
      end

      context "failure がない場合" do
        it "失敗はありませんと表示されること" do
          get admin_singing_recap_movie_batch_execution_path(execution)
          expect(response.body).to include("失敗はありません")
        end
      end

      context "failure がある場合" do
        let!(:failure) do
          FactoryBot.create(:singing_recap_movie_batch_failure,
                            singing_recap_movie_batch_execution: execution,
                            customer: customer,
                            year: execution.year,
                            error_class: "RuntimeError",
                            error_message: "Something went badly wrong")
        end

        it "失敗ユーザー一覧が表示されること" do
          get admin_singing_recap_movie_batch_execution_path(execution)
          expect(response.body).to include("失敗ユーザー一覧")
          expect(response.body).to include(customer.name)
        end

        it "エラークラスが表示されること" do
          get admin_singing_recap_movie_batch_execution_path(execution)
          expect(response.body).to include("RuntimeError")
        end

        it "エラーメッセージが表示されること" do
          get admin_singing_recap_movie_batch_execution_path(execution)
          expect(response.body).to include("Something went badly wrong")
        end

        it "failure が複数ある場合に件数が表示されること" do
          customer2 = FactoryBot.create(:customer, domain_name: "singing")
          FactoryBot.create(:singing_recap_movie_batch_failure,
                            singing_recap_movie_batch_execution: execution,
                            customer: customer2,
                            year: execution.year)
          get admin_singing_recap_movie_batch_execution_path(execution)
          expect(response.body).to include("2 件")
        end

        it "retry_status が表示されること" do
          get admin_singing_recap_movie_batch_execution_path(execution)
          expect(response.body).to include("pending")
        end
      end

      it "一覧に戻るリンクが表示されること" do
        get admin_singing_recap_movie_batch_execution_path(execution)
        expect(response.body).to include(admin_singing_recap_movies_path)
      end

      it "存在しない ID では 404 になること" do
        expect {
          get admin_singing_recap_movie_batch_execution_path(id: 999_999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "POST /admin/singing/recap_movie_batch_executions/:id/retry_failures" do
      context "retry 対象 failure がある場合" do
        let!(:failure) do
          FactoryBot.create(:singing_recap_movie_batch_failure,
                            singing_recap_movie_batch_execution: execution,
                            customer: customer,
                            year: execution.year,
                            retry_status: "pending")
        end

        before do
          allow(Singing::GenerateRecapMovieJob).to receive(:perform_later)
        end

        it "show にリダイレクトすること" do
          post retry_failures_admin_singing_recap_movie_batch_execution_path(execution)
          expect(response).to redirect_to(admin_singing_recap_movie_batch_execution_path(execution))
        end

        it "成功 flash メッセージが表示されること" do
          post retry_failures_admin_singing_recap_movie_batch_execution_path(execution)
          expect(flash[:notice]).to include("再実行を予約しました")
        end

        it "failure の retry_status が retried になること" do
          post retry_failures_admin_singing_recap_movie_batch_execution_path(execution)
          expect(failure.reload.retry_status).to eq("retried")
        end
      end

      context "execution が active（running）な場合" do
        let(:running_execution) do
          FactoryBot.create(:singing_recap_movie_batch_execution, :running, admin: admin)
        end

        it "alert メッセージでリダイレクトされること" do
          post retry_failures_admin_singing_recap_movie_batch_execution_path(running_execution)
          expect(response).to redirect_to(admin_singing_recap_movie_batch_execution_path(running_execution))
          expect(flash[:alert]).to include("実行中")
        end
      end

      context "retry 対象の failure がない場合" do
        let!(:retried_failure) do
          FactoryBot.create(:singing_recap_movie_batch_failure, :retried,
                            singing_recap_movie_batch_execution: execution,
                            customer: customer,
                            year: execution.year)
        end

        it "alert メッセージでリダイレクトされること" do
          post retry_failures_admin_singing_recap_movie_batch_execution_path(execution)
          expect(response).to redirect_to(admin_singing_recap_movie_batch_execution_path(execution))
          expect(flash[:alert]).to include("再実行対象の failure がありません")
        end
      end
    end
  end

  describe "非管理者アクセス" do
    it "管理者ログインなしでは show にアクセスできないこと" do
      get admin_singing_recap_movie_batch_execution_path(execution)
      expect(response).to redirect_to(new_admin_session_path)
    end

    it "管理者ログインなしでは retry_failures にアクセスできないこと" do
      post retry_failures_admin_singing_recap_movie_batch_execution_path(execution)
      expect(response).to redirect_to(new_admin_session_path)
    end
  end
end
