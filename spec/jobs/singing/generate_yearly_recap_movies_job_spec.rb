require "rails_helper"

RSpec.describe Singing::GenerateYearlyRecapMoviesJob, type: :job do
  let(:year) { 2024 }
  let(:year_mid) { Time.zone.local(year, 6, 1) }

  def singing_customer
    create(:customer, domain_name: "singing")
  end

  def completed_diagnosis(customer, created_at: year_mid)
    create(:singing_diagnosis, :completed, customer: customer, created_at: created_at)
  end

  describe "#perform" do
    context "指定年に completed diagnosis がある Singing ユーザー" do
      it "movie を pending として作成する" do
        customer = singing_customer
        completed_diagnosis(customer)

        described_class.perform_now(year)

        movie = SingingGeneratedRecapMovie.find_by(customer: customer, year: year)
        expect(movie).to be_present
        expect(movie.status).to eq("pending")
      end
    end

    context "completed diagnosis がないユーザー" do
      it "対象外のため movie を作成しない" do
        singing_customer

        described_class.perform_now(year)

        expect(SingingGeneratedRecapMovie.count).to eq(0)
      end
    end

    context "指定年以外の diagnosis しかないユーザー" do
      it "対象外のため movie を作成しない" do
        customer = singing_customer
        completed_diagnosis(customer, created_at: Time.zone.local(year - 1, 6, 1))

        described_class.perform_now(year)

        expect(SingingGeneratedRecapMovie.where(customer: customer, year: year)).to be_empty
      end
    end

    context "pending movie が既にある場合" do
      it "重複作成しない" do
        customer = singing_customer
        completed_diagnosis(customer)
        existing = create(:singing_generated_recap_movie, customer: customer, year: year, status: :pending)

        described_class.perform_now(year)

        expect(SingingGeneratedRecapMovie.where(customer: customer, year: year).count).to eq(1)
        expect(existing.reload.status).to eq("pending")
      end
    end

    context "processing movie が既にある場合" do
      it "重複作成しない" do
        customer = singing_customer
        completed_diagnosis(customer)
        existing = create(:singing_generated_recap_movie, :processing, customer: customer, year: year)

        described_class.perform_now(year)

        expect(SingingGeneratedRecapMovie.where(customer: customer, year: year).count).to eq(1)
        expect(existing.reload.status).to eq("processing")
      end
    end

    context "completed movie が既にある場合" do
      it "ステータスを変更しない" do
        customer = singing_customer
        completed_diagnosis(customer)
        existing = create(:singing_generated_recap_movie, :completed, customer: customer, year: year)

        described_class.perform_now(year)

        expect(existing.reload.status).to eq("completed")
      end
    end

    context "failed movie が既にある場合" do
      it "status を pending に戻す" do
        customer = singing_customer
        completed_diagnosis(customer)
        movie = create(:singing_generated_recap_movie, :failed, customer: customer, year: year)

        described_class.perform_now(year)

        expect(movie.reload.status).to eq("pending")
        expect(movie.reload.error_message).to be_nil
      end
    end

    context "expired movie が既にある場合" do
      it "status を pending に戻す" do
        customer = singing_customer
        completed_diagnosis(customer)
        movie = create(:singing_generated_recap_movie, :expired, customer: customer, year: year)

        described_class.perform_now(year)

        expect(movie.reload.status).to eq("pending")
      end
    end

    context "同じ year で2回実行した場合" do
      it "movie が重複しない" do
        customer = singing_customer
        completed_diagnosis(customer)

        described_class.perform_now(year)
        described_class.perform_now(year)

        expect(SingingGeneratedRecapMovie.where(customer: customer, year: year).count).to eq(1)
      end
    end

    describe "execution status 更新" do
    let(:execution) do
      FactoryBot.create(:singing_recap_movie_batch_execution, year: year, status: :enqueued)
    end

    it "job 開始時に execution status が running になること" do
      customer = singing_customer
      completed_diagnosis(customer)

      described_class.perform_now(year, execution.id)

      expect(execution.reload.status).to eq("completed")
    end

    it "execution_id を渡すと job 正常終了後に completed になること" do
      described_class.perform_now(year, execution.id)
      expect(execution.reload.status).to eq("completed")
    end

    it "execution_id なしで最新 enqueued を自動検出して completed にすること" do
      execution  # 事前に生成しておく（lazy let を強制評価）
      described_class.perform_now(year)
      expect(execution.reload.status).to eq("completed")
    end

    it "job が例外を raise した場合 execution status が failed になること" do
      # Customer.joins がループ外で例外を raise → 外側の rescue で failed になる
      allow(Customer).to receive(:joins).and_raise(RuntimeError, "db error")

      expect {
        described_class.perform_now(year, execution.id)
      }.to raise_error(RuntimeError, "db error")

      expect(execution.reload.status).to eq("failed")
    end

    it "execution log が存在しない execution_id でも job が落ちないこと" do
      customer = singing_customer
      completed_diagnosis(customer)

      expect {
        described_class.perform_now(year, 999_999)
      }.not_to raise_error
    end

    it "execution log が存在しない（nil）場合でも job が落ちないこと" do
      customer = singing_customer
      completed_diagnosis(customer)

      expect {
        described_class.perform_now(year, nil)
      }.not_to raise_error
    end

    describe "progress 更新" do
      it "job 開始時に started_at がセットされること" do
        described_class.perform_now(year, execution.id)
        expect(execution.reload.started_at).to be_present
      end

      it "job 開始時に total_movies_count が更新されること" do
        customer = singing_customer
        completed_diagnosis(customer)

        described_class.perform_now(year, execution.id)

        expect(execution.reload.total_movies_count).to eq(1)
      end

      it "対象なし（0件）の場合も total_movies_count が 0 になること" do
        described_class.perform_now(year, execution.id)
        expect(execution.reload.total_movies_count).to eq(0)
      end

      it "pending 化成功で completed_movies_count が増加すること" do
        customer = singing_customer
        completed_diagnosis(customer)

        described_class.perform_now(year, execution.id)

        expect(execution.reload.completed_movies_count).to eq(1)
      end

      it "prepare 例外時に failed_movies_count が増加すること" do
        customer = singing_customer
        completed_diagnosis(customer)

        allow_any_instance_of(described_class).to receive(:find_or_prepare_movie!)
          .and_raise(StandardError, "prepare error")

        described_class.perform_now(year, execution.id)

        expect(execution.reload.failed_movies_count).to eq(1)
        expect(execution.reload.completed_movies_count).to eq(0)
      end

      it "正常終了時に finished_at がセットされること" do
        described_class.perform_now(year, execution.id)
        expect(execution.reload.finished_at).to be_present
      end

      it "job 例外時にも finished_at がセットされること" do
        allow(Customer).to receive(:joins).and_raise(RuntimeError, "db error")

        expect {
          described_class.perform_now(year, execution.id)
        }.to raise_error(RuntimeError)

        expect(execution.reload.finished_at).to be_present
      end
    end
  end

  it "pending/skipped 件数をログに出力する" do
      customer = singing_customer
      completed_diagnosis(customer)
      create(:singing_generated_recap_movie, :completed, customer: customer, year: year)

      other = singing_customer
      completed_diagnosis(other)

      logged = []
      allow(Rails.logger).to receive(:info) { |msg| logged << msg }

      described_class.perform_now(year)

      expect(logged).to include(match(/\[RecapMovieBatch\] year=#{year} pending=1 skipped=1/))
    end

    describe "actual result summary 保存" do
      let(:execution) do
        FactoryBot.create(:singing_recap_movie_batch_execution, year: year, status: :enqueued)
      end

      it "新規作成した件数が actual_created_movies_count に保存されること" do
        customer = singing_customer
        completed_diagnosis(customer)

        described_class.perform_now(year, execution.id)

        expect(execution.reload.actual_created_movies_count).to eq(1)
      end

      it "再生成した件数が actual_regenerated_movies_count に保存されること" do
        customer = singing_customer
        completed_diagnosis(customer)
        create(:singing_generated_recap_movie, :failed, customer: customer, year: year)

        described_class.perform_now(year, execution.id)

        expect(execution.reload.actual_regenerated_movies_count).to eq(1)
        expect(execution.reload.actual_created_movies_count).to eq(0)
      end

      it "スキップした件数が actual_skipped_movies_count に保存されること" do
        customer = singing_customer
        completed_diagnosis(customer)
        create(:singing_generated_recap_movie, :completed, customer: customer, year: year)

        described_class.perform_now(year, execution.id)

        expect(execution.reload.actual_skipped_movies_count).to eq(1)
      end

      it "新規・再生成・スキップが混在する場合に正しく集計されること" do
        customer1 = singing_customer
        completed_diagnosis(customer1)

        customer2 = singing_customer
        completed_diagnosis(customer2)
        create(:singing_generated_recap_movie, :failed, customer: customer2, year: year)

        customer3 = singing_customer
        completed_diagnosis(customer3)
        create(:singing_generated_recap_movie, :completed, customer: customer3, year: year)

        described_class.perform_now(year, execution.id)

        exec = execution.reload
        expect(exec.actual_created_movies_count).to eq(1)
        expect(exec.actual_regenerated_movies_count).to eq(1)
        expect(exec.actual_skipped_movies_count).to eq(1)
      end

      it "対象なしの場合は actual_* がすべて 0 になること" do
        described_class.perform_now(year, execution.id)

        exec = execution.reload
        expect(exec.actual_created_movies_count).to eq(0)
        expect(exec.actual_regenerated_movies_count).to eq(0)
        expect(exec.actual_skipped_movies_count).to eq(0)
      end

      it "prepare 例外が発生した場合は actual_skipped に計上されないこと" do
        customer = singing_customer
        completed_diagnosis(customer)

        allow_any_instance_of(described_class).to receive(:find_or_prepare_movie!)
          .and_raise(StandardError, "prepare error")

        described_class.perform_now(year, execution.id)

        exec = execution.reload
        expect(exec.actual_created_movies_count).to eq(0)
        expect(exec.actual_skipped_movies_count).to eq(0)
        expect(exec.failed_movies_count).to eq(1)
      end
    end

    describe "failure tracking" do
      let(:execution) do
        FactoryBot.create(:singing_recap_movie_batch_execution, year: year, status: :enqueued)
      end

      it "prepare 例外時に failure record が作成されること" do
        customer = singing_customer
        completed_diagnosis(customer)

        allow_any_instance_of(described_class).to receive(:find_or_prepare_movie!)
          .and_raise(StandardError, "prepare failed")

        described_class.perform_now(year, execution.id)

        failure = execution.failures.last
        expect(failure).to be_present
        expect(failure.customer).to eq(customer)
        expect(failure.year).to eq(year)
        expect(failure.error_class).to eq("StandardError")
        expect(failure.error_message).to eq("prepare failed")
        expect(failure.failed_at).to be_present
      end

      it "failure record に backtrace_excerpt が保存されること" do
        customer = singing_customer
        completed_diagnosis(customer)

        allow_any_instance_of(described_class).to receive(:find_or_prepare_movie!)
          .and_raise(StandardError, "prepare failed")

        described_class.perform_now(year, execution.id)

        failure = execution.failures.last
        expect(failure.backtrace_excerpt).to be_present
      end

      it "find_or_prepare_movie! 例外時に recap_movie_id が nil の failure が作成されること" do
        customer = singing_customer
        completed_diagnosis(customer)

        allow_any_instance_of(described_class).to receive(:find_or_prepare_movie!)
          .and_raise(StandardError, "db error in prepare")

        described_class.perform_now(year, execution.id)

        failure = execution.failures.last
        expect(failure).to be_present
        expect(failure.recap_movie_id).to be_nil
      end

      it "execution なしでは failure record を作成しないこと" do
        customer = singing_customer
        completed_diagnosis(customer)

        allow_any_instance_of(described_class).to receive(:find_or_prepare_movie!)
          .and_raise(StandardError, "prepare failed")

        expect {
          described_class.perform_now(year, nil)
        }.not_to change(SingingRecapMovieBatchFailure, :count)
      end

      it "複数 customer で失敗した場合に複数の failure record が作成されること" do
        customer1 = singing_customer
        completed_diagnosis(customer1)
        customer2 = singing_customer
        completed_diagnosis(customer2)

        allow_any_instance_of(described_class).to receive(:find_or_prepare_movie!)
          .and_raise(StandardError, "prepare failed")

        described_class.perform_now(year, execution.id)

        expect(execution.failures.count).to eq(2)
      end
    end
  end
end
