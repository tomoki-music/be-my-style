require 'rails_helper'

RSpec.describe SingingRecapMovieBatchExecution, type: :model do
  let(:admin) { FactoryBot.create(:admin) }

  describe "バリデーション" do
    subject(:execution) do
      FactoryBot.build(:singing_recap_movie_batch_execution, admin: admin)
    end

    it "有効なレコードが作成できること" do
      expect(execution).to be_valid
    end

    it "year が必須であること" do
      execution.year = nil
      expect(execution).not_to be_valid
      expect(execution.errors[:year]).to be_present
    end

    it "year が整数でなければ無効であること" do
      execution.year = 2025.5
      expect(execution).not_to be_valid
    end

    it "year が 2000 以下は無効であること" do
      execution.year = 2000
      expect(execution).not_to be_valid
    end

    it "year が 2100 を超えると無効であること" do
      execution.year = 2101
      expect(execution).not_to be_valid
    end

    it "status が必須であること" do
      execution.status = nil
      expect(execution).not_to be_valid
    end

    it "admin が nil でも有効であること（optional）" do
      execution.admin = nil
      expect(execution).to be_valid
    end
  end

  describe "#skipped_breakdown_hash" do
    it "skipped_breakdown が nil の場合は空ハッシュを返すこと" do
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, skipped_breakdown: nil)
      expect(execution.skipped_breakdown_hash).to eq({})
    end

    it "skipped_breakdown が存在する場合はその値を返すこと" do
      breakdown = { "pending" => 2, "processing" => 1, "completed" => 0 }
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, skipped_breakdown: breakdown)
      expect(execution.skipped_breakdown_hash).to eq(breakdown)
    end
  end

  describe "enum status" do
    it "enqueued ステータスが使えること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin)
      expect(execution.enqueued?).to be true
    end

    it "running ステータスが使えること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin, status: :running)
      expect(execution.running?).to be true
    end

    it "completed ステータスが使えること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin, status: :completed)
      expect(execution.completed?).to be true
    end

    it "failed ステータスが使えること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin, status: :failed)
      expect(execution.failed?).to be true
    end
  end

  describe ".active_for_year" do
    let(:year) { 2025 }

    it "enqueued のレコードを返すこと" do
      exec = FactoryBot.create(:singing_recap_movie_batch_execution, year: year, status: :enqueued)
      expect(SingingRecapMovieBatchExecution.active_for_year(year)).to include(exec)
    end

    it "running のレコードを返すこと" do
      exec = FactoryBot.create(:singing_recap_movie_batch_execution, year: year, status: :running)
      expect(SingingRecapMovieBatchExecution.active_for_year(year)).to include(exec)
    end

    it "completed のレコードは返さないこと" do
      FactoryBot.create(:singing_recap_movie_batch_execution, year: year, status: :completed)
      expect(SingingRecapMovieBatchExecution.active_for_year(year)).to be_empty
    end

    it "failed のレコードは返さないこと" do
      FactoryBot.create(:singing_recap_movie_batch_execution, year: year, status: :failed)
      expect(SingingRecapMovieBatchExecution.active_for_year(year)).to be_empty
    end

    it "別の year のレコードは返さないこと" do
      FactoryBot.create(:singing_recap_movie_batch_execution, year: year + 1, status: :enqueued)
      expect(SingingRecapMovieBatchExecution.active_for_year(year)).to be_empty
    end
  end

  describe "#active?" do
    it "enqueued の場合は true を返すこと" do
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, status: :enqueued)
      expect(execution.active?).to be true
    end

    it "running の場合は true を返すこと" do
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, status: :running)
      expect(execution.active?).to be true
    end

    it "completed の場合は false を返すこと" do
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, status: :completed)
      expect(execution.active?).to be false
    end

    it "failed の場合は false を返すこと" do
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, status: :failed)
      expect(execution.active?).to be false
    end
  end

  describe "belongs_to :admin" do
    it "admin に紐付けられること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin)
      expect(execution.admin).to eq(admin)
    end

    it "admin なしで作成できること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: nil)
      expect(execution.admin).to be_nil
    end
  end

  describe "カウント項目" do
    it "デフォルト値が 0 であること" do
      execution = SingingRecapMovieBatchExecution.new(year: 2025, status: :enqueued)
      expect(execution.target_customers_count).to eq(0)
      expect(execution.new_movies_count).to eq(0)
      expect(execution.regenerate_movies_count).to eq(0)
      expect(execution.skipped_movies_count).to eq(0)
    end

    it "progress カラムのデフォルト値が 0 であること" do
      execution = SingingRecapMovieBatchExecution.new(year: 2025, status: :enqueued)
      expect(execution.total_movies_count).to eq(0)
      expect(execution.completed_movies_count).to eq(0)
      expect(execution.failed_movies_count).to eq(0)
    end

    it "actual_* カラムのデフォルト値が 0 であること" do
      execution = SingingRecapMovieBatchExecution.new(year: 2025, status: :enqueued)
      expect(execution.actual_created_movies_count).to eq(0)
      expect(execution.actual_regenerated_movies_count).to eq(0)
      expect(execution.actual_skipped_movies_count).to eq(0)
    end
  end

  describe "#result_summary_available?" do
    it "actual_* がすべて 0 の場合は false を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              actual_created_movies_count:     0,
                              actual_regenerated_movies_count: 0,
                              actual_skipped_movies_count:     0)
      expect(exec.result_summary_available?).to be false
    end

    it "actual_created が 1 以上の場合は true を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              actual_created_movies_count: 5)
      expect(exec.result_summary_available?).to be true
    end

    it "actual_regenerated が 1 以上の場合は true を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              actual_regenerated_movies_count: 3)
      expect(exec.result_summary_available?).to be true
    end

    it "actual_skipped が 1 以上の場合は true を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              actual_skipped_movies_count: 2)
      expect(exec.result_summary_available?).to be true
    end
  end

  describe "#enqueue_success_rate" do
    it "actual_* と failed がすべて 0 の場合は nil を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              actual_created_movies_count:     0,
                              actual_regenerated_movies_count: 0,
                              failed_movies_count:             0)
      expect(exec.enqueue_success_rate).to be_nil
    end

    it "failed が 0 で全件 enqueue 成功の場合は 100.0 を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              actual_created_movies_count:     7,
                              actual_regenerated_movies_count: 3,
                              failed_movies_count:             0)
      expect(exec.enqueue_success_rate).to eq(100.0)
    end

    it "一部 failed がある場合は正しい割合を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              actual_created_movies_count:     8,
                              actual_regenerated_movies_count: 0,
                              failed_movies_count:             2)
      expect(exec.enqueue_success_rate).to eq(80.0)
    end

    it "全件 failed の場合は 0.0 を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              actual_created_movies_count:     0,
                              actual_regenerated_movies_count: 0,
                              failed_movies_count:             5)
      expect(exec.enqueue_success_rate).to eq(0.0)
    end
  end

  describe "#progress_percent" do
    it "total が 0 の場合は 0 を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution, total_movies_count: 0)
      expect(exec.progress_percent).to eq(0)
    end

    it "completed + failed / total を % で返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              total_movies_count: 10,
                              completed_movies_count: 6,
                              failed_movies_count: 2)
      expect(exec.progress_percent).to eq(80)
    end

    it "100% を超えないこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              total_movies_count: 10,
                              completed_movies_count: 10,
                              failed_movies_count: 5)
      expect(exec.progress_percent).to eq(100)
    end

    it "すべて completed の場合は 100 を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              total_movies_count: 5,
                              completed_movies_count: 5,
                              failed_movies_count: 0)
      expect(exec.progress_percent).to eq(100)
    end
  end

  describe "#remaining_movies_count" do
    it "total が 0 の場合は 0 を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution, total_movies_count: 0)
      expect(exec.remaining_movies_count).to eq(0)
    end

    it "total - completed - failed を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              total_movies_count: 10,
                              completed_movies_count: 6,
                              failed_movies_count: 1)
      expect(exec.remaining_movies_count).to eq(3)
    end

    it "0 未満にならないこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              total_movies_count: 5,
                              completed_movies_count: 5,
                              failed_movies_count: 5)
      expect(exec.remaining_movies_count).to eq(0)
    end
  end

  describe "retry summary メソッド" do
    let!(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin) }
    let(:customer1)  { FactoryBot.create(:customer) }
    let(:customer2)  { FactoryBot.create(:customer) }
    let(:customer3)  { FactoryBot.create(:customer) }
    let(:customer4)  { FactoryBot.create(:customer) }

    before do
      FactoryBot.create(:singing_recap_movie_batch_failure,
                        singing_recap_movie_batch_execution: execution,
                        customer: customer1, retry_status: "pending")
      FactoryBot.create(:singing_recap_movie_batch_failure, :retried,
                        singing_recap_movie_batch_execution: execution,
                        customer: customer2)
      FactoryBot.create(:singing_recap_movie_batch_failure, :skipped,
                        singing_recap_movie_batch_execution: execution,
                        customer: customer3)
      FactoryBot.create(:singing_recap_movie_batch_failure, :retry_failed,
                        singing_recap_movie_batch_execution: execution,
                        customer: customer4)
    end

    it "#retry_pending_count が pending 件数を返すこと" do
      expect(execution.retry_pending_count).to eq(1)
    end

    it "#retry_retried_count が retried 件数を返すこと" do
      expect(execution.retry_retried_count).to eq(1)
    end

    it "#retry_skipped_count が skipped 件数を返すこと" do
      expect(execution.retry_skipped_count).to eq(1)
    end

    it "#retry_failed_count が retry_failed 件数を返すこと" do
      expect(execution.retry_failed_count).to eq(1)
    end

    it "#retry_success_rate が retried / (retried + failed + skipped) * 100 を返すこと" do
      # retried=1, failed=1, skipped=1 → 1/3 ≒ 33.3
      expect(execution.retry_success_rate).to eq(33.3)
    end

    it "#retry_success_rate は処理済みがない場合 nil を返すこと" do
      exec2 = FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin)
      FactoryBot.create(:singing_recap_movie_batch_failure,
                        singing_recap_movie_batch_execution: exec2,
                        customer: FactoryBot.create(:customer),
                        retry_status: "pending")
      expect(exec2.retry_success_rate).to be_nil
    end

    it "#has_any_retried? は非pending failure がある場合 true を返すこと" do
      expect(execution.has_any_retried?).to be true
    end

    it "#has_any_retried? は全 pending の場合 false を返すこと" do
      exec2 = FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin)
      FactoryBot.create(:singing_recap_movie_batch_failure,
                        singing_recap_movie_batch_execution: exec2,
                        customer: FactoryBot.create(:customer),
                        retry_status: "pending")
      expect(exec2.has_any_retried?).to be false
    end
  end

  describe "#duration_seconds" do
    it "started_at が nil の場合は nil を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution, started_at: nil, finished_at: nil)
      expect(exec.duration_seconds).to be_nil
    end

    it "finished_at がある場合は started_at から finished_at までの秒数を返すこと" do
      t = Time.current
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              started_at: t - 90.seconds,
                              finished_at: t)
      expect(exec.duration_seconds).to eq(90)
    end

    it "finished_at が nil の場合は現在時刻との差を返すこと" do
      exec = FactoryBot.build(:singing_recap_movie_batch_execution,
                              started_at: 1.minute.ago,
                              finished_at: nil)
      expect(exec.duration_seconds).to be_between(58, 62)
    end
  end
end
