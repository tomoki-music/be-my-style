require "rails_helper"

RSpec.describe Singing::RecapMovieAutoRetryService, type: :service do
  include ActiveJob::TestHelper

  let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed) }
  let(:customer)  { FactoryBot.create(:customer, domain_name: "singing") }

  subject(:result) { described_class.call }

  describe ".call" do
    context "due な auto_retry_scheduled failure がない場合" do
      it "processed_count が 0 であること" do
        expect(result.processed_count).to eq(0)
      end

      it "成功すること（エラーなし）" do
        expect { result }.not_to raise_error
      end
    end

    context "due な auto_retry_scheduled failure が 1 件ある場合" do
      let!(:failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure,
                          :auto_retry_due,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer,
                          year: execution.year)
      end

      before do
        allow(Singing::GenerateRecapMovieJob).to receive(:perform_later)
      end

      it "processed_count が 1 であること" do
        expect(result.processed_count).to eq(1)
      end

      it "succeeded_count が 1 であること" do
        expect(result.succeeded_count).to eq(1)
      end

      it "auto_retry_status が running になること" do
        result
        expect(failure.reload.auto_retry_status).to eq("running")
      end

      it "auto_retry_attempts_count が 1 増えること" do
        expect { result }.to change { failure.reload.auto_retry_attempts_count }.by(1)
      end

      it "retry_status が retried になること" do
        result
        expect(failure.reload.retry_status).to eq("retried")
      end

      it "GenerateRecapMovieJob が enqueue されること" do
        result
        expect(Singing::GenerateRecapMovieJob).to have_received(:perform_later)
      end

      it "last_auto_retry_at が設定されること" do
        result
        expect(failure.reload.last_auto_retry_at).not_to be_nil
      end
    end

    context "next_auto_retry_at が未来の failure は処理されないこと" do
      let!(:not_due_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure,
                          :auto_retry_scheduled,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer,
                          year: execution.year)
      end

      it "processed_count が 0 であること" do
        expect(result.processed_count).to eq(0)
      end
    end

    context "auto_retry_status が scheduled でない failure は処理されないこと" do
      let!(:failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer,
                          year: execution.year,
                          auto_retry_status: "not_applicable",
                          next_auto_retry_at: 1.minute.ago)
      end

      it "processed_count が 0 であること" do
        expect(result.processed_count).to eq(0)
      end
    end

    context "active batch が存在する場合（同年）" do
      let!(:failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure,
                          :auto_retry_due,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer,
                          year: execution.year)
      end
      let!(:active_execution) do
        FactoryBot.create(:singing_recap_movie_batch_execution,
                          :running,
                          year: execution.year)
      end

      it "skipped_count が 1 であること" do
        expect(result.skipped_count).to eq(1)
      end

      it "retry_status が pending のままであること" do
        result
        expect(failure.reload.retry_status).to eq("pending")
      end

      it "auto_retry_status が scheduled のままであること（reschedule）" do
        result
        # active batch が終わればまた due になるよう scheduled に戻す
        expect(failure.reload.auto_retry_status).to eq("scheduled")
      end
    end

    context "MAX_ATTEMPTS に達した場合" do
      let!(:failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure,
                          :auto_retry_due,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer,
                          year: execution.year,
                          auto_retry_attempts_count: SingingRecapMovieBatchFailure::AUTO_RETRY_MAX_ATTEMPTS)
      end

      before do
        allow(Singing::GenerateRecapMovieJob).to receive(:perform_later)
        allow(Singing::RecapMovieAutoRetryService).to receive(:new).and_call_original
      end

      # attempts >= MAX の場合は reschedule_or_exhaust が exhausted にする
      # このテストは service が rescue 後に exhausted にする流れを確認
      it "failure が exhausted になること（GenerateRecapMovieJob 失敗時）" do
        allow(Singing::RecapMovieFailureRetryService).to receive(:call).and_return(
          Singing::RecapMovieFailureRetryService::Result.new(
            success?: false,
            message: "some error",
            movie: nil
          )
        )
        result
        expect(failure.reload.auto_retry_status).to eq("exhausted")
      end
    end
  end
end
