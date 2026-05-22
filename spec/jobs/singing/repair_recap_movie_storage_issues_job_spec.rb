require "rails_helper"

RSpec.describe Singing::RepairRecapMovieStorageIssuesJob, type: :job do
  let(:customer)  { create(:customer, domain_name: "singing") }
  let(:customer2) { create(:customer, domain_name: "singing") }

  def attach_video(movie)
    movie.video_file.attach(
      io:           StringIO.new("MP4"),
      filename:     "recap_test.mp4",
      content_type: "video/mp4",
    )
    movie
  end

  def cleaned_but_attached_movie
    m = create(:singing_generated_recap_movie, :expired, customer: customer,
               cleaned_up_at: 1.hour.ago)
    attach_video(m)
    m
  end

  def completed_without_file_movie
    m = create(:singing_generated_recap_movie, :completed, customer: customer2)
    m.video_file.detach
    m
  end

  describe "#perform (dry_run: true — デフォルト)" do
    subject(:result) { described_class.perform_now }

    context "異常なし" do
      it "Result を返すこと" do
        expect(result).to be_a(Singing::RecapMovieStorageRepairService::Result)
      end

      it "repaired 件数が 0 であること" do
        expect(result.repaired_cba_count).to eq(0)
        expect(result.repaired_cwf_count).to eq(0)
      end

      it "No anomalies ログを出力すること" do
        logged = []
        allow(Rails.logger).to receive(:info) { |msg| logged << msg }
        result
        expect(logged).to include(match(/No anomalies detected/))
      end
    end

    context "cleaned_but_attached がある場合" do
      before { cleaned_but_attached_movie }

      it "Anomalies detected ログを出力すること" do
        logged = []
        allow(Rails.logger).to receive(:info) { |msg| logged << msg }
        result
        expect(logged).to include(match(/Anomalies detected/))
      end

      it "実際には purge_later を呼ばないこと (dry_run)" do
        expect_any_instance_of(ActiveStorage::Attached::One).not_to receive(:purge_later)
        result
      end

      it "repaired_cba_count が 1 であること" do
        expect(result.repaired_cba_count).to eq(1)
      end
    end

    context "completed_without_file がある場合" do
      let!(:cwf) { completed_without_file_movie }

      it "status を変更しないこと (dry_run)" do
        result
        expect(cwf.reload.status).to eq("completed")
      end

      it "repaired_cwf_count が 1 であること" do
        expect(result.repaired_cwf_count).to eq(1)
      end
    end
  end

  describe "#perform (dry_run: false — 実際に修復)" do
    subject(:result) { described_class.perform_now(dry_run: false) }

    context "cleaned_but_attached がある場合" do
      let!(:cba) { cleaned_but_attached_movie }

      it "purge_later を呼ぶこと" do
        expect_any_instance_of(ActiveStorage::Attached::One).to receive(:purge_later)
        result
      end

      it "repaired_cba_count が 1 であること" do
        expect(result.repaired_cba_count).to eq(1)
      end

      it "dry_run=false を返すこと" do
        expect(result.dry_run).to be false
      end
    end

    context "completed_without_file がある場合" do
      let!(:cwf) { completed_without_file_movie }

      it "status を failed に変更すること" do
        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:purge_later)
        result
        expect(cwf.reload.status).to eq("failed")
      end

      it "repaired_cwf_count が 1 であること" do
        expect(result.repaired_cwf_count).to eq(1)
      end
    end

    context "両方の異常がある場合" do
      let!(:cba) { cleaned_but_attached_movie }
      let!(:cwf) { completed_without_file_movie }

      it "両方を修復すること" do
        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:purge_later)
        result
        expect(cwf.reload.status).to eq("failed")
        expect(result.repaired_cba_count).to eq(1)
        expect(result.repaired_cwf_count).to eq(1)
      end
    end
  end

  describe "BATCH_LIMIT" do
    it "定数が定義されていること" do
      expect(described_class::BATCH_LIMIT).to be_a(Integer)
      expect(described_class::BATCH_LIMIT).to be > 0
    end
  end
end
