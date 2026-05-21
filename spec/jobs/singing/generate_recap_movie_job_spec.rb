require "rails_helper"

RSpec.describe Singing::GenerateRecapMovieJob, type: :job do
  let(:customer) { create(:customer, domain_name: "singing") }

  describe "#perform" do
    context "movie が存在しない場合" do
      it "何もしない（エラーにならない）" do
        expect { described_class.perform_now(0) }.not_to raise_error
      end
    end

    context "status が pending でない場合" do
      %i[processing completed failed expired].each do |s|
        it "#{s} のときは何もしない" do
          movie = create(:singing_generated_recap_movie, s, customer: customer)
          expect { described_class.perform_now(movie.id) }
            .not_to change { movie.reload.status }
        end
      end
    end

    context "status が pending の場合" do
      let(:movie) { create(:singing_generated_recap_movie, customer: customer) }

      it "Singing::RecapMovieRenderer を呼ぶ" do
        renderer = instance_double(Singing::RecapMovieRenderer, call: true)
        allow(Singing::RecapMovieRenderer).to receive(:new).with(movie).and_return(renderer)
        described_class.perform_now(movie.id)
        expect(renderer).to have_received(:call)
      end
    end

    context "perform 中に例外が発生した場合" do
      let(:movie) { create(:singing_generated_recap_movie, customer: customer) }

      before do
        allow(SingingGeneratedRecapMovie).to receive(:find_by).and_return(movie)
        allow(Singing::RecapMovieRenderer).to receive(:new).and_raise(StandardError, "unexpected error")
        allow(Singing::RecapMovieRetryReconciliationService).to receive(:call)
      end

      it "例外を再 raise しない" do
        expect { described_class.perform_now(movie.id) }.not_to raise_error
      end

      it "status が failed になる" do
        described_class.perform_now(movie.id)
        expect(movie.reload.status).to eq("failed")
      end

      it "error_message に例外メッセージが入る" do
        described_class.perform_now(movie.id)
        expect(movie.reload.error_message).to eq("unexpected error")
      end

      it "reconciliation service を呼ぶこと" do
        described_class.perform_now(movie.id)
        expect(Singing::RecapMovieRetryReconciliationService).to have_received(:call)
      end
    end

    context "reconciliation" do
      let(:execution) { create(:singing_recap_movie_batch_execution, :completed) }
      let(:movie)     { create(:singing_generated_recap_movie, customer: customer) }

      before do
        allow(Singing::RecapMovieRenderer).to receive(:new).with(movie) do
          instance_double(Singing::RecapMovieRenderer, call: true).tap do
            movie.update!(status: :completed)
          end
        end
      end

      it "renderer 呼び出し後に reconciliation service を呼ぶこと" do
        allow(Singing::RecapMovieRetryReconciliationService).to receive(:call)
        described_class.perform_now(movie.id)
        expect(Singing::RecapMovieRetryReconciliationService).to have_received(:call)
      end

      context "retried failure が存在し movie が completed になった場合" do
        let!(:failure) do
          create(:singing_recap_movie_batch_failure, :retried,
                 singing_recap_movie_batch_execution: execution,
                 customer: customer,
                 year: movie.year)
        end

        it "failure が resolved になること" do
          described_class.perform_now(movie.id)
          expect(failure.reload.retry_status).to eq("resolved")
        end
      end

      context "retried failure が存在し movie が failed になった場合" do
        let!(:failure) do
          create(:singing_recap_movie_batch_failure, :retried,
                 singing_recap_movie_batch_execution: execution,
                 customer: customer,
                 year: movie.year)
        end

        before do
          allow(Singing::RecapMovieRenderer).to receive(:new).with(movie) do
            instance_double(Singing::RecapMovieRenderer, call: false).tap do
              movie.update!(status: :failed, error_message: "render failed")
            end
          end
        end

        it "failure が retry_failed になること" do
          described_class.perform_now(movie.id)
          expect(failure.reload.retry_status).to eq("retry_failed")
        end
      end
    end
  end
end
