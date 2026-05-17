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

      it "processing を経て failed になる" do
        described_class.perform_now(movie.id)
        expect(movie.reload.status).to eq("failed")
      end

      it "error_message に未実装メッセージが入る" do
        described_class.perform_now(movie.id)
        expect(movie.reload.error_message).to eq(
          Singing::GenerateRecapMovieJob::RENDERER_NOT_IMPLEMENTED_MESSAGE
        )
      end
    end

    context "perform 中に例外が発生した場合" do
      let(:movie) { create(:singing_generated_recap_movie, customer: customer) }

      before do
        allow(movie).to receive(:mark_processing!).and_raise(StandardError, "unexpected error")
        allow(SingingGeneratedRecapMovie).to receive(:find_by).and_return(movie)
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
    end
  end
end
