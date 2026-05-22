require "rails_helper"

RSpec.describe Singing::RecapMovieStorageRepairService do
  let(:customer)  { create(:customer, domain_name: "singing") }
  let(:customer2) { create(:customer, domain_name: "singing") }

  # ── Helpers ──────────────────────────────────────────────────────────

  def attach_video(movie)
    movie.video_file.attach(
      io:           StringIO.new("MP4"),
      filename:     "recap_test.mp4",
      content_type: "video/mp4",
    )
    movie
  end

  def completed_without_file
    m = create(:singing_generated_recap_movie, :completed, customer: customer)
    m.video_file.detach
    m
  end

  def cleaned_but_attached
    m = create(:singing_generated_recap_movie, :expired, customer: customer2,
               cleaned_up_at: 1.hour.ago)
    attach_video(m)
    m
  end

  # ── Result ───────────────────────────────────────────────────────────

  describe "Result struct" do
    it "必要なキーを持つこと" do
      r = described_class::Result.new(
        repaired_cba_count: 1, repaired_cwf_count: 2, dry_run: true
      )
      expect(r.repaired_cba_count).to eq(1)
      expect(r.repaired_cwf_count).to eq(2)
      expect(r.dry_run).to be true
    end
  end

  # ── dry_run: true (デフォルト) ────────────────────────────────────────

  describe ".call (dry_run: true)" do
    subject(:result) { described_class.call(dry_run: true) }

    context "cleaned_but_attached がある場合" do
      let!(:movie) { cleaned_but_attached }

      it "dry_run=true を返すこと" do
        expect(result.dry_run).to be true
      end

      it "repaired_cba_count が 1 であること" do
        expect(result.repaired_cba_count).to eq(1)
      end

      it "実際には purge_later を呼ばないこと" do
        expect_any_instance_of(ActiveStorage::Attached::One).not_to receive(:purge_later)
        result
      end

      it "video_file が detach されていないこと" do
        result
        expect(movie.reload.video_file).to be_attached
      end

      it "[DRY_RUN] ログを出力すること" do
        logged = []
        allow(Rails.logger).to receive(:info) { |msg| logged << msg }
        result
        expect(logged).to include(match(/\[RecapMovieRepair\] \[DRY_RUN\] cleaned_but_attached/))
      end
    end

    context "completed_without_file がある場合" do
      let!(:movie) { completed_without_file }

      it "repaired_cwf_count が 1 であること" do
        expect(result.repaired_cwf_count).to eq(1)
      end

      it "実際には status を変更しないこと" do
        result
        expect(movie.reload.status).to eq("completed")
      end

      it "[DRY_RUN] ログを出力すること" do
        logged = []
        allow(Rails.logger).to receive(:info) { |msg| logged << msg }
        result
        expect(logged).to include(match(/\[RecapMovieRepair\] \[DRY_RUN\] completed_without_file/))
      end
    end

    context "異常なし" do
      it "repaired_cba_count が 0 であること" do
        expect(result.repaired_cba_count).to eq(0)
      end

      it "repaired_cwf_count が 0 であること" do
        expect(result.repaired_cwf_count).to eq(0)
      end
    end
  end

  # ── dry_run: false (実際に修復) ───────────────────────────────────────

  describe ".call (dry_run: false)" do
    subject(:result) { described_class.call(dry_run: false) }

    context "cleaned_but_attached がある場合" do
      let!(:movie) { cleaned_but_attached }

      it "dry_run=false を返すこと" do
        expect(result.dry_run).to be false
      end

      it "repaired_cba_count が 1 であること" do
        expect(result.repaired_cba_count).to eq(1)
      end

      it "purge_later を呼び出すこと" do
        expect_any_instance_of(ActiveStorage::Attached::One).to receive(:purge_later)
        result
      end

      it "ログを出力すること" do
        logged = []
        allow(Rails.logger).to receive(:info) { |msg| logged << msg }
        result
        expect(logged).to include(match(/\[RecapMovieRepair\] cleaned_but_attached: purge_later enqueued/))
      end
    end

    context "completed_without_file がある場合" do
      let!(:movie) { completed_without_file }

      it "repaired_cwf_count が 1 であること" do
        expect(result.repaired_cwf_count).to eq(1)
      end

      it "status を failed に変更すること" do
        result
        expect(movie.reload.status).to eq("failed")
      end

      it "error_message に修復理由が記録されること" do
        result
        expect(movie.reload.error_message).to include("Storage Repair")
      end

      it "ログを出力すること" do
        logged = []
        allow(Rails.logger).to receive(:info) { |msg| logged << msg }
        result
        expect(logged).to include(match(/\[RecapMovieRepair\] completed_without_file: mark_failed!/))
      end
    end

    context "両方の異常がある場合" do
      let!(:cwf_movie) { completed_without_file }
      let!(:cba_movie) { cleaned_but_attached }

      it "両方を修復すること" do
        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:purge_later)
        result
        expect(cwf_movie.reload.status).to eq("failed")
        expect(result.repaired_cba_count).to eq(1)
        expect(result.repaired_cwf_count).to eq(1)
      end
    end
  end

  # ── Safety: 対象外レコード ────────────────────────────────────────────

  describe "Safety — 対象外レコードは触れないこと" do
    context "completed_without_file: completed + video_file あり" do
      let!(:healthy_movie) { create(:singing_generated_recap_movie, :completed, customer: customer) }

      it "status が変わらないこと" do
        described_class.call(dry_run: false)
        expect(healthy_movie.reload.status).to eq("completed")
      end
    end

    context "cleaned_but_attached: expired + cleaned_up_at なし + attachment あり" do
      let!(:uncleaned) do
        m = create(:singing_generated_recap_movie, :expired, customer: customer, cleaned_up_at: nil)
        attach_video(m)
        m
      end

      it "purge_later を呼ばないこと" do
        expect_any_instance_of(ActiveStorage::Attached::One).not_to receive(:purge_later)
        described_class.call(dry_run: false)
      end
    end

    context "completed_without_file: failed movie は対象外" do
      let!(:failed_movie) { create(:singing_generated_recap_movie, :failed, customer: customer) }

      it "status が変わらないこと" do
        described_class.call(dry_run: false)
        expect(failed_movie.reload.status).to eq("failed")
        expect(failed_movie.reload.error_message).to eq("Remotion render failed")
      end
    end
  end

  # ── REPAIR_BATCH_LIMIT ───────────────────────────────────────────────

  describe "REPAIR_BATCH_LIMIT" do
    it "定数が定義されていること" do
      expect(described_class::REPAIR_BATCH_LIMIT).to be_a(Integer)
      expect(described_class::REPAIR_BATCH_LIMIT).to be > 0
    end

    it "limit を超える対象があっても limit 件しか処理しないこと" do
      stub_const("Singing::RecapMovieStorageRepairService::REPAIR_BATCH_LIMIT", 1)

      c1 = create(:customer, domain_name: "singing")
      c2 = create(:customer, domain_name: "singing")
      m1 = create(:singing_generated_recap_movie, :expired, customer: c1, cleaned_up_at: 1.hour.ago)
      m2 = create(:singing_generated_recap_movie, :expired, customer: c2, cleaned_up_at: 1.hour.ago)
      attach_video(m1)
      attach_video(m2)

      allow_any_instance_of(ActiveStorage::Attached::One).to receive(:purge_later)

      result = described_class.call(dry_run: false, limit: 1)
      expect(result.repaired_cba_count).to eq(1)
    end
  end

  # ── エラー耐性 ──────────────────────────────────────────────────────

  describe "エラー耐性" do
    context "1 件が例外を起こしても残りを処理し raise しないこと" do
      let!(:cba1) { cleaned_but_attached }
      let!(:cba2) do
        m = create(:singing_generated_recap_movie, :expired, customer: create(:customer, domain_name: "singing"),
                   cleaned_up_at: 2.hours.ago)
        attach_video(m)
        m
      end

      it "job 自体は例外を raise しないこと" do
        call_count = 0
        allow_any_instance_of(ActiveStorage::Attached::One).to receive(:purge_later) do
          call_count += 1
          raise "S3 error" if call_count == 1
        end

        expect { described_class.call(dry_run: false) }.not_to raise_error
      end
    end
  end
end
