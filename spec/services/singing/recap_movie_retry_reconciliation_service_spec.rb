require "rails_helper"

RSpec.describe Singing::RecapMovieRetryReconciliationService, type: :service do
  let(:customer)  { FactoryBot.create(:customer, domain_name: "singing") }
  let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed) }

  let(:movie) do
    FactoryBot.create(:singing_generated_recap_movie,
                      customer: customer,
                      year:     execution.year)
  end

  let!(:retried_failure) do
    FactoryBot.create(:singing_recap_movie_batch_failure, :retried,
                      singing_recap_movie_batch_execution: execution,
                      customer: customer,
                      year:     execution.year)
  end

  describe ".call" do
    context "movie が completed の場合" do
      before { movie.update!(status: "completed") }

      it "retried failure を resolved に更新すること" do
        described_class.call(movie)
        expect(retried_failure.reload.retry_status).to eq("resolved")
      end

      it "resolved_at が設定されること" do
        described_class.call(movie)
        expect(retried_failure.reload.resolved_at).not_to be_nil
      end

      it "resolved_movie_id が movie.id になること" do
        described_class.call(movie)
        expect(retried_failure.reload.resolved_movie_id).to eq(movie.id)
      end
    end

    context "movie が failed の場合" do
      before { movie.update!(status: "failed", error_message: "render error") }

      it "retried failure を retry_failed に更新すること" do
        described_class.call(movie)
        expect(retried_failure.reload.retry_status).to eq("retry_failed")
      end

      it "retry_error_message に movie の error_message が入ること" do
        described_class.call(movie)
        expect(retried_failure.reload.retry_error_message).to eq("render error")
      end

      it "resolved_at は nil のままであること" do
        described_class.call(movie)
        expect(retried_failure.reload.resolved_at).to be_nil
      end
    end

    context "movie が processing の場合（完了前）" do
      before { movie.update!(status: "processing") }

      it "failure を更新しないこと" do
        expect { described_class.call(movie) }
          .not_to change { retried_failure.reload.retry_status }
      end
    end

    context "対象となる retried failure が存在しない場合" do
      before do
        retried_failure.update!(retry_status: "pending")
        movie.update!(status: "completed")
      end

      it "エラーを raise しないこと" do
        expect { described_class.call(movie) }.not_to raise_error
      end
    end

    context "同一 customer の別年の retried failure がある場合" do
      let!(:other_year_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure, :retried,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer,
                          year:     execution.year + 1)
      end

      before { movie.update!(status: "completed") }

      it "同一年の failure だけ resolved になること" do
        described_class.call(movie)
        expect(retried_failure.reload.retry_status).to eq("resolved")
        expect(other_year_failure.reload.retry_status).to eq("retried")
      end
    end

    context "同一年・別 customer の retried failure がある場合" do
      let(:other_customer) { FactoryBot.create(:customer, domain_name: "singing") }
      let!(:other_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure, :retried,
                          singing_recap_movie_batch_execution: execution,
                          customer: other_customer,
                          year:     execution.year)
      end

      before { movie.update!(status: "completed") }

      it "movie の customer の failure だけ resolved になること" do
        described_class.call(movie)
        expect(retried_failure.reload.retry_status).to eq("resolved")
        expect(other_failure.reload.retry_status).to eq("retried")
      end
    end

    context "auto retry 実行中（auto_retry_status: running）で movie が failed の場合" do
      before { movie.update!(status: "failed", error_message: "render error") }

      context "attempts が MAX 未満の場合" do
        let!(:auto_retried_failure) do
          FactoryBot.create(:singing_recap_movie_batch_failure,
                            :auto_retry_running,
                            singing_recap_movie_batch_execution: execution,
                            customer: customer,
                            year:     execution.year,
                            retry_status: "retried",
                            auto_retry_attempts_count: 1)
        end

        it "retry_status が pending にリセットされること" do
          described_class.call(movie)
          expect(auto_retried_failure.reload.retry_status).to eq("pending")
        end

        it "auto_retry_status が scheduled になること" do
          described_class.call(movie)
          expect(auto_retried_failure.reload.auto_retry_status).to eq("scheduled")
        end

        it "next_auto_retry_at が設定されること" do
          described_class.call(movie)
          expect(auto_retried_failure.reload.next_auto_retry_at).not_to be_nil
        end

        it "auto_retry_error_message に movie の error_message が入ること" do
          described_class.call(movie)
          expect(auto_retried_failure.reload.auto_retry_error_message).to eq("render error")
        end
      end

      context "attempts が MAX 以上の場合" do
        let!(:exhausted_failure) do
          FactoryBot.create(:singing_recap_movie_batch_failure,
                            :auto_retry_running,
                            singing_recap_movie_batch_execution: execution,
                            customer: customer,
                            year:     execution.year,
                            retry_status: "retried",
                            auto_retry_attempts_count: SingingRecapMovieBatchFailure::AUTO_RETRY_MAX_ATTEMPTS)
        end

        it "retry_status が retry_failed になること" do
          described_class.call(movie)
          expect(exhausted_failure.reload.retry_status).to eq("retry_failed")
        end

        it "auto_retry_status が exhausted になること" do
          described_class.call(movie)
          expect(exhausted_failure.reload.auto_retry_status).to eq("exhausted")
        end
      end
    end

    context "通常の手動 retry（auto_retry_status: not_applicable）で movie が failed の場合" do
      before { movie.update!(status: "failed", error_message: "render error") }

      it "retry_status が retry_failed になること（既存の動作）" do
        described_class.call(movie)
        expect(retried_failure.reload.retry_status).to eq("retry_failed")
      end

      it "auto_retry_status は not_applicable のままであること" do
        described_class.call(movie)
        expect(retried_failure.reload.auto_retry_status).to eq("not_applicable")
      end
    end
  end
end
