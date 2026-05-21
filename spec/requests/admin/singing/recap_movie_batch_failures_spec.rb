require "rails_helper"

RSpec.describe "Admin::Singing::RecapMovieBatchFailures", type: :request do
  let(:admin)    { FactoryBot.create(:admin) }
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin) }

  let!(:failure) do
    FactoryBot.create(:singing_recap_movie_batch_failure,
                      singing_recap_movie_batch_execution: execution,
                      customer: customer,
                      year: execution.year,
                      retry_status: "pending")
  end

  describe "管理者ログイン済み" do
    before { sign_in admin }

    describe "POST /admin/singing/recap_movie_batch_failures/:id/retry" do
      before do
        allow(Singing::GenerateRecapMovieJob).to receive(:perform_later)
      end

      it "execution show にリダイレクトすること" do
        post retry_admin_singing_recap_movie_batch_failure_path(failure)
        expect(response).to redirect_to(
          admin_singing_recap_movie_batch_execution_path(execution)
        )
      end

      it "成功 flash メッセージが表示されること" do
        post retry_admin_singing_recap_movie_batch_failure_path(failure)
        expect(flash[:notice]).to include("再実行を予約しました")
      end

      it "failure の retry_status が retried になること" do
        post retry_admin_singing_recap_movie_batch_failure_path(failure)
        expect(failure.reload.retry_status).to eq("retried")
      end

      context "すでに retry 済みの場合" do
        before { failure.update!(retry_status: "retried") }

        it "alert メッセージでリダイレクトされること" do
          post retry_admin_singing_recap_movie_batch_failure_path(failure)
          expect(response).to redirect_to(
            admin_singing_recap_movie_batch_execution_path(execution)
          )
          expect(flash[:alert]).to be_present
        end
      end

      context "同一年の active batch がある場合" do
        before do
          FactoryBot.create(:singing_recap_movie_batch_execution,
                            :running,
                            year: execution.year)
        end

        it "alert メッセージでリダイレクトされること" do
          post retry_admin_singing_recap_movie_batch_failure_path(failure)
          expect(flash[:alert]).to include("Batch が実行中")
        end
      end

      it "存在しない ID では 404 になること" do
        expect {
          post retry_admin_singing_recap_movie_batch_failure_path(id: 999_999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "非管理者アクセス" do
    it "管理者ログインなしでは retry にアクセスできないこと" do
      post retry_admin_singing_recap_movie_batch_failure_path(failure)
      expect(response).to redirect_to(new_admin_session_path)
    end
  end
end
