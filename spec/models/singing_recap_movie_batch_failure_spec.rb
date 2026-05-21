require "rails_helper"

RSpec.describe SingingRecapMovieBatchFailure, type: :model do
  let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution) }
  let(:customer)  { FactoryBot.create(:customer) }

  describe "バリデーション" do
    subject(:failure) do
      FactoryBot.build(:singing_recap_movie_batch_failure,
                       singing_recap_movie_batch_execution: execution,
                       customer: customer)
    end

    it "有効なレコードが作成できること" do
      expect(failure).to be_valid
    end

    it "year が必須であること" do
      failure.year = nil
      expect(failure).not_to be_valid
      expect(failure.errors[:year]).to be_present
    end

    it "year が整数でなければ無効であること" do
      failure.year = 2025.5
      expect(failure).not_to be_valid
    end

    it "error_class が必須であること" do
      failure.error_class = nil
      expect(failure).not_to be_valid
      expect(failure.errors[:error_class]).to be_present
    end

    it "failed_at が必須であること" do
      failure.failed_at = nil
      expect(failure).not_to be_valid
      expect(failure.errors[:failed_at]).to be_present
    end

    it "recap_movie_id が nil でも有効であること（optional）" do
      failure.recap_movie_id = nil
      expect(failure).to be_valid
    end
  end

  describe "belongs_to" do
    it "execution に紐付けられること" do
      failure = FactoryBot.create(:singing_recap_movie_batch_failure,
                                  singing_recap_movie_batch_execution: execution,
                                  customer: customer)
      expect(failure.singing_recap_movie_batch_execution).to eq(execution)
    end

    it "customer に紐付けられること" do
      failure = FactoryBot.create(:singing_recap_movie_batch_failure,
                                  singing_recap_movie_batch_execution: execution,
                                  customer: customer)
      expect(failure.customer).to eq(customer)
    end

    it "recap_movie と紐付けられること" do
      movie = FactoryBot.create(:singing_generated_recap_movie, customer: customer)
      failure = FactoryBot.create(:singing_recap_movie_batch_failure,
                                  singing_recap_movie_batch_execution: execution,
                                  customer: customer,
                                  recap_movie_id: movie.id)
      expect(failure.recap_movie).to eq(movie)
    end
  end

  describe "has_many :failures (SingingRecapMovieBatchExecution 側)" do
    it "execution.failures でアクセスできること" do
      failure = FactoryBot.create(:singing_recap_movie_batch_failure,
                                  singing_recap_movie_batch_execution: execution,
                                  customer: customer)
      expect(execution.failures).to include(failure)
    end

    it "execution を削除すると failure も削除されること（dependent: :destroy）" do
      FactoryBot.create(:singing_recap_movie_batch_failure,
                        singing_recap_movie_batch_execution: execution,
                        customer: customer)
      expect { execution.destroy }.to change(SingingRecapMovieBatchFailure, :count).by(-1)
    end
  end

  describe "フィールド保存" do
    it "error_message が保存できること" do
      failure = FactoryBot.create(:singing_recap_movie_batch_failure,
                                  singing_recap_movie_batch_execution: execution,
                                  customer: customer,
                                  error_message: "DB connection failed")
      expect(failure.reload.error_message).to eq("DB connection failed")
    end

    it "backtrace_excerpt が保存できること" do
      bt = "app/jobs/singing/generate_yearly_recap_movies_job.rb:38"
      failure = FactoryBot.create(:singing_recap_movie_batch_failure,
                                  singing_recap_movie_batch_execution: execution,
                                  customer: customer,
                                  backtrace_excerpt: bt)
      expect(failure.reload.backtrace_excerpt).to eq(bt)
    end

    it "metadata が JSON として保存できること" do
      meta = { "extra" => "info" }
      failure = FactoryBot.create(:singing_recap_movie_batch_failure,
                                  singing_recap_movie_batch_execution: execution,
                                  customer: customer,
                                  metadata: meta)
      expect(failure.reload.metadata).to eq(meta)
    end
  end

  describe "retry_status enum" do
    subject(:failure) do
      FactoryBot.create(:singing_recap_movie_batch_failure,
                        singing_recap_movie_batch_execution: execution,
                        customer: customer)
    end

    it "デフォルトが pending であること" do
      expect(failure.retry_status).to eq("pending")
    end

    it "retried に遷移できること" do
      failure.update!(retry_status: :retried)
      expect(failure.reload.retry_status).to eq("retried")
    end

    it "skipped に遷移できること" do
      failure.update!(retry_status: :skipped)
      expect(failure.reload.retry_status).to eq("skipped")
    end

    it "retry_failed に遷移できること" do
      failure.update!(retry_status: :retry_failed)
      expect(failure.reload.retry_status).to eq("retry_failed")
    end
  end

  describe "#retryable?" do
    it "retry_status が pending の場合 true を返すこと" do
      failure = FactoryBot.create(:singing_recap_movie_batch_failure,
                                  singing_recap_movie_batch_execution: execution,
                                  customer: customer,
                                  retry_status: "pending")
      expect(failure.retryable?).to be true
    end

    it "retry_status が retried の場合 false を返すこと" do
      failure = FactoryBot.create(:singing_recap_movie_batch_failure, :retried,
                                  singing_recap_movie_batch_execution: execution,
                                  customer: customer)
      expect(failure.retryable?).to be false
    end

    it "retry_status が skipped の場合 false を返すこと" do
      failure = FactoryBot.create(:singing_recap_movie_batch_failure, :skipped,
                                  singing_recap_movie_batch_execution: execution,
                                  customer: customer)
      expect(failure.retryable?).to be false
    end
  end

  describe ".retryable scope" do
    it "retry_status が pending の failure のみを返すこと" do
      pending_failure = FactoryBot.create(:singing_recap_movie_batch_failure,
                                          singing_recap_movie_batch_execution: execution,
                                          customer: customer,
                                          retry_status: "pending")
      retried_failure = FactoryBot.create(:singing_recap_movie_batch_failure, :retried,
                                          singing_recap_movie_batch_execution: execution,
                                          customer: FactoryBot.create(:customer))
      result = SingingRecapMovieBatchFailure.retryable
      expect(result).to include(pending_failure)
      expect(result).not_to include(retried_failure)
    end
  end
end
