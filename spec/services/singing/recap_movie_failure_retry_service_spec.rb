require "rails_helper"

RSpec.describe Singing::RecapMovieFailureRetryService, type: :service do
  let(:admin)     { FactoryBot.create(:admin) }
  let(:customer)  { FactoryBot.create(:customer, domain_name: "singing") }
  let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed) }

  let(:failure) do
    FactoryBot.create(:singing_recap_movie_batch_failure,
                      singing_recap_movie_batch_execution: execution,
                      customer: customer,
                      year: execution.year,
                      retry_status: "pending")
  end

  subject(:result) { described_class.call(failure: failure, admin: admin) }

  describe "正常系: retry_status が pending で active batch がない場合" do
    context "recap_movie が存在しない場合" do
      it "成功を返すこと" do
        expect(result.success?).to be true
      end

      it "Recap Movie を新規作成すること" do
        expect { result }.to change(SingingGeneratedRecapMovie, :count).by(1)
      end

      it "新規作成した movie が pending 状態であること" do
        result
        movie = SingingGeneratedRecapMovie.find_by(customer: customer, year: execution.year)
        expect(movie.status).to eq("pending")
      end

      it "failure の retry_status を retried に更新すること" do
        result
        expect(failure.reload.retry_status).to eq("retried")
      end

      it "failure の retried_at が設定されること" do
        result
        expect(failure.reload.retried_at).not_to be_nil
      end

      it "failure の retried_by_id が admin の id になること" do
        result
        expect(failure.reload.retried_by_id).to eq(admin.id)
      end
    end

    context "recap_movie が failed 状態で存在する場合" do
      let(:movie) do
        FactoryBot.create(:singing_generated_recap_movie,
                          customer: customer,
                          year: execution.year,
                          status: "failed")
      end

      before { failure.update!(recap_movie_id: movie.id) }

      it "成功を返すこと" do
        expect(result.success?).to be true
      end

      it "movie の status を pending にリセットすること" do
        result
        expect(movie.reload.status).to eq("pending")
      end

      it "新規 movie を作成しないこと" do
        expect { result }.not_to change(SingingGeneratedRecapMovie, :count)
      end
    end

    context "recap_movie が expired 状態で存在する場合" do
      let(:movie) do
        FactoryBot.create(:singing_generated_recap_movie,
                          customer: customer,
                          year: execution.year,
                          status: "expired")
      end

      before { failure.update!(recap_movie_id: movie.id) }

      it "成功を返すこと" do
        expect(result.success?).to be true
      end

      it "movie の status を pending にリセットすること" do
        result
        expect(movie.reload.status).to eq("pending")
      end
    end
  end

  describe "異常系: retry_status が pending でない場合" do
    before { failure.update!(retry_status: "retried") }

    it "失敗を返すこと" do
      expect(result.success?).to be false
    end

    it "エラーメッセージを返すこと" do
      expect(result.message).to include("retry済み")
    end
  end

  describe "異常系: 同一年の active batch が存在する場合" do
    before do
      FactoryBot.create(:singing_recap_movie_batch_execution,
                        :running,
                        year: execution.year)
    end

    it "失敗を返すこと" do
      expect(result.success?).to be false
    end

    it "Batch 実行中のメッセージを返すこと" do
      expect(result.message).to include("Batch が実行中")
    end

    it "failure の retry_status を skipped にすること" do
      result
      expect(failure.reload.retry_status).to eq("skipped")
    end
  end

  describe "異常系: recap_movie が completed（reusable）な場合" do
    let(:movie) do
      FactoryBot.create(:singing_generated_recap_movie,
                        customer: customer,
                        year: execution.year,
                        status: "completed",
                        expires_at: nil)
    end

    before { failure.update!(recap_movie_id: movie.id) }

    it "失敗を返すこと" do
      expect(result.success?).to be false
    end

    it "retry 不要のメッセージを返すこと" do
      expect(result.message).to include("completed のため再実行不要")
    end

    it "failure の retry_status を skipped にすること" do
      result
      expect(failure.reload.retry_status).to eq("skipped")
    end
  end
end
