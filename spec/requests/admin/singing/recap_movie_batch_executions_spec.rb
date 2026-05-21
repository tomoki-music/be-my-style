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
  end

  describe "非管理者アクセス" do
    it "管理者ログインなしでは show にアクセスできないこと" do
      get admin_singing_recap_movie_batch_execution_path(execution)
      expect(response).to redirect_to(new_admin_session_path)
    end
  end
end
