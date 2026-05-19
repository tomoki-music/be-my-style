require "rails_helper"

RSpec.describe Singing::CleanupGeneratedRecapMoviesJob, type: :job do
  let(:customer) { create(:customer, domain_name: "singing") }

  describe "#perform" do
    context "期限切れ completed movie がある場合" do
      it "video_file を purge_later し status を expired にする" do
        movie = create(:singing_generated_recap_movie, :completed, customer: customer, expires_at: 1.second.ago)
        expect(movie.video_file).to be_attached

        expect_any_instance_of(ActiveStorage::Attached::One).to receive(:purge_later)

        described_class.perform_now

        expect(movie.reload.status).to eq("expired")
        expect(movie.reload.error_message).to be_nil
      end
    end

    context "期限切れ pending movie がある場合" do
      it "status を expired にする" do
        movie = create(:singing_generated_recap_movie, customer: customer, status: :pending, expires_at: 1.second.ago)
        described_class.perform_now
        expect(movie.reload.status).to eq("expired")
      end
    end

    context "期限切れ processing movie がある場合" do
      it "status を expired にする" do
        movie = create(:singing_generated_recap_movie, customer: customer, status: :processing, expires_at: 1.second.ago)
        described_class.perform_now
        expect(movie.reload.status).to eq("expired")
      end
    end

    context "期限切れ failed movie がある場合" do
      it "status を expired にする" do
        movie = create(:singing_generated_recap_movie, :failed, customer: customer, expires_at: 1.second.ago)
        described_class.perform_now
        expect(movie.reload.status).to eq("expired")
      end
    end

    context "already expired な movie がある場合" do
      it "対象外のため status は変わらない" do
        movie = create(:singing_generated_recap_movie, :expired, customer: customer)
        expect { described_class.perform_now }.not_to change { movie.reload.updated_at }
      end
    end

    context "expires_at が nil の movie がある場合" do
      it "対象外のため status は変わらない" do
        movie = create(:singing_generated_recap_movie, :completed, customer: customer, expires_at: nil)
        described_class.perform_now
        expect(movie.reload.status).to eq("completed")
      end
    end

    context "expires_at が未来の movie がある場合" do
      it "対象外のため status は変わらない" do
        movie = create(:singing_generated_recap_movie, :completed, customer: customer, expires_at: 1.day.from_now)
        described_class.perform_now
        expect(movie.reload.status).to eq("completed")
      end
    end

    it "cleanup ログを出力する" do
      create(:singing_generated_recap_movie, :completed, customer: customer, expires_at: 1.second.ago)
      logged = []
      allow(Rails.logger).to receive(:info) { |msg| logged << msg }
      described_class.perform_now
      expect(logged).to include(match(/\[RecapMovieCleanup\] expired movie_id=\d+ year=\d+ customer_id=\d+/))
    end

    it "1 件が expire! で例外を起こしても残りを処理し、job 自体は例外を raise しない" do
      other = create(:customer, domain_name: "singing")
      broken = create(:singing_generated_recap_movie, customer: customer, status: :pending, expires_at: 1.second.ago)
      healthy = create(:singing_generated_recap_movie, customer: other, status: :pending, expires_at: 1.second.ago)

      allow_any_instance_of(SingingGeneratedRecapMovie).to receive(:expire!).and_call_original
      allow(SingingGeneratedRecapMovie).to receive(:find_by).and_call_original
      call_count = 0
      allow_any_instance_of(SingingGeneratedRecapMovie).to receive(:expire!) do |movie|
        call_count += 1
        raise "boom" if movie.id == broken.id

        movie.update!(status: :expired)
      end

      expect { described_class.perform_now }.not_to raise_error
      expect(healthy.reload.status).to eq("expired")
    end
  end
end
