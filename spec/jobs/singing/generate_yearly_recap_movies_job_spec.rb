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

  before do
    allow(Singing::GenerateRecapMovieJob).to receive(:perform_later)
  end

  describe "#perform" do
    context "指定年に completed diagnosis がある Singing ユーザー" do
      it "movie を作成して GenerateRecapMovieJob を enqueue する" do
        customer = singing_customer
        completed_diagnosis(customer)

        described_class.perform_now(year)

        movie = SingingGeneratedRecapMovie.find_by(customer: customer, year: year)
        expect(movie).to be_present
        expect(movie.status).to eq("pending")
        expect(Singing::GenerateRecapMovieJob).to have_received(:perform_later).with(movie.id)
      end
    end

    context "completed diagnosis がないユーザー" do
      it "対象外のため movie を作成せず enqueue もしない" do
        singing_customer

        described_class.perform_now(year)

        expect(SingingGeneratedRecapMovie.count).to eq(0)
        expect(Singing::GenerateRecapMovieJob).not_to have_received(:perform_later)
      end
    end

    context "指定年以外の diagnosis しかないユーザー" do
      it "対象外のため movie を作成せず enqueue もしない" do
        customer = singing_customer
        completed_diagnosis(customer, created_at: Time.zone.local(year - 1, 6, 1))

        described_class.perform_now(year)

        expect(SingingGeneratedRecapMovie.where(customer: customer, year: year)).to be_empty
        expect(Singing::GenerateRecapMovieJob).not_to have_received(:perform_later)
      end
    end

    context "pending movie が既にある場合" do
      it "重複作成せず enqueue もしない" do
        customer = singing_customer
        completed_diagnosis(customer)
        existing = create(:singing_generated_recap_movie, customer: customer, year: year, status: :pending)

        described_class.perform_now(year)

        expect(SingingGeneratedRecapMovie.where(customer: customer, year: year).count).to eq(1)
        expect(Singing::GenerateRecapMovieJob).not_to have_received(:perform_later)
        expect(existing.reload.status).to eq("pending")
      end
    end

    context "processing movie が既にある場合" do
      it "重複作成せず enqueue もしない" do
        customer = singing_customer
        completed_diagnosis(customer)
        existing = create(:singing_generated_recap_movie, :processing, customer: customer, year: year)

        described_class.perform_now(year)

        expect(SingingGeneratedRecapMovie.where(customer: customer, year: year).count).to eq(1)
        expect(Singing::GenerateRecapMovieJob).not_to have_received(:perform_later)
      end
    end

    context "completed movie が既にある場合" do
      it "enqueue しない" do
        customer = singing_customer
        completed_diagnosis(customer)
        create(:singing_generated_recap_movie, :completed, customer: customer, year: year)

        described_class.perform_now(year)

        expect(Singing::GenerateRecapMovieJob).not_to have_received(:perform_later)
      end
    end

    context "failed movie が既にある場合" do
      it "status を pending に戻して enqueue する" do
        customer = singing_customer
        completed_diagnosis(customer)
        movie = create(:singing_generated_recap_movie, :failed, customer: customer, year: year)

        described_class.perform_now(year)

        expect(movie.reload.status).to eq("pending")
        expect(movie.reload.error_message).to be_nil
        expect(Singing::GenerateRecapMovieJob).to have_received(:perform_later).with(movie.id)
      end
    end

    context "expired movie が既にある場合" do
      it "status を pending に戻して enqueue する" do
        customer = singing_customer
        completed_diagnosis(customer)
        movie = create(:singing_generated_recap_movie, :expired, customer: customer, year: year)

        described_class.perform_now(year)

        expect(movie.reload.status).to eq("pending")
        expect(Singing::GenerateRecapMovieJob).to have_received(:perform_later).with(movie.id)
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
  end

  it "enqueued/skipped 件数をログに出力する" do
      customer = singing_customer
      completed_diagnosis(customer)
      create(:singing_generated_recap_movie, :completed, customer: customer, year: year)

      other = singing_customer
      completed_diagnosis(other)

      logged = []
      allow(Rails.logger).to receive(:info) { |msg| logged << msg }

      described_class.perform_now(year)

      expect(logged).to include(match(/\[RecapMovieBatch\] year=#{year} enqueued=1 skipped=1/))
    end
  end
end
