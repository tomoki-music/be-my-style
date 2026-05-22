require 'rails_helper'

RSpec.describe Singing::RecapMovieHealthDashboardService do
  subject(:result) { described_class.call }

  let(:admin)    { FactoryBot.create(:admin) }
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }

  describe ".call" do
    it "必要なキーを全て返すこと" do
      expect(result.keys).to contain_exactly(
        :summary, :trends, :error_analysis, :open_failures, :slow_batches,
        :auto_retry_summary, :auto_retry_failures, :storage_expiry, :storage_audit
      )
    end

    it "storage_audit に必要なキーが含まれること" do
      expect(result[:storage_audit].keys).to include(
        :completed_without_file_count,
        :cleaned_but_attached_count,
        :has_anomalies,
        :audited_at,
      )
    end
  end

  describe "#build_summary" do
    subject(:summary) { result[:summary] }

    context "バッチ実行が存在しない場合" do
      it "total_batches が 0 であること" do
        expect(summary[:total_batches]).to eq(0)
      end

      it "batch_success_rate が 0 であること" do
        expect(summary[:batch_success_rate]).to eq(0)
      end

      it "retry_recovery_rate が 0 であること" do
        expect(summary[:retry_recovery_rate]).to eq(0)
      end

      it "open_failures が 0 であること" do
        expect(summary[:open_failures]).to eq(0)
      end

      it "avg_render_duration が nil であること" do
        expect(summary[:avg_render_duration]).to be_nil
      end
    end

    context "completed / failed バッチが混在する場合" do
      before do
        FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin, year: 2024)
        FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin, year: 2025)
        FactoryBot.create(:singing_recap_movie_batch_execution, :failed,    admin: admin, year: 2023)
      end

      it "total_batches が全件数を返すこと" do
        expect(summary[:total_batches]).to eq(3)
      end

      it "batch_success_rate が completed / total の割合であること" do
        expect(summary[:batch_success_rate]).to eq(66.7)
      end
    end

    context "retry failure が存在する場合" do
      let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin) }

      before do
        FactoryBot.create(:singing_recap_movie_batch_failure, :resolved,
                          singing_recap_movie_batch_execution: execution, customer: customer)
        FactoryBot.create(:singing_recap_movie_batch_failure, :retry_failed,
                          singing_recap_movie_batch_execution: execution, customer: customer)
      end

      it "retry_recovery_rate を計算すること" do
        # resolved=1, retry_attempted=2 (retried+resolved+retry_failed) -> 50%
        # ただし :resolved trait は retry_status="resolved" なので retried には含まれない
        # retried=0, resolved=1, retry_failed=1 -> attempted=2 -> 50%
        expect(summary[:retry_recovery_rate]).to eq(50.0)
      end

      it "open_failures が retry_failed を含むこと" do
        expect(summary[:open_failures]).to eq(1)
      end
    end

    context "pending failure が存在する場合" do
      let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin) }

      before do
        FactoryBot.create(:singing_recap_movie_batch_failure,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer,
                          retry_status: "pending")
      end

      it "open_failures が pending を含むこと" do
        expect(summary[:open_failures]).to eq(1)
      end
    end

    context "started_at / finished_at が設定されたバッチが存在する場合" do
      before do
        FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin)
      end

      it "avg_render_duration が整数を返すこと" do
        expect(summary[:avg_render_duration]).to be_a(Integer).and(be > 0)
      end
    end
  end

  describe "#build_trends" do
    subject(:trends) { result[:trends] }

    it "30日分の配列を返すこと" do
      expect(trends.size).to eq(31)
    end

    it "各要素が必要なキーを持つこと" do
      expect(trends.first.keys).to contain_exactly(
        :date, :total_batches, :completed_batches, :failed_batches,
        :failure_count, :resolved_count
      )
    end

    context "直近30日以内にバッチ実行がある場合" do
      before do
        FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin,
                          created_at: 1.day.ago)
      end

      it "当日付近のエントリに件数が反映されること" do
        total = trends.sum { |t| t[:total_batches] }
        expect(total).to eq(1)
      end
    end

    context "30日より古いバッチは集計対象外" do
      before do
        FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin,
                          created_at: 40.days.ago)
      end

      it "trends の total_batches 合計が 0 であること" do
        total = trends.sum { |t| t[:total_batches] }
        expect(total).to eq(0)
      end
    end
  end

  describe "#build_error_analysis" do
    subject(:error_analysis) { result[:error_analysis] }

    context "failure が存在しない場合" do
      it "空ハッシュを返すこと" do
        expect(error_analysis).to eq({})
      end
    end

    context "複数 error_class の failure が存在する場合" do
      let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin) }

      before do
        3.times do
          FactoryBot.create(:singing_recap_movie_batch_failure,
                            singing_recap_movie_batch_execution: execution,
                            customer: customer,
                            error_class: "Open3::Timeout")
        end
        2.times do
          FactoryBot.create(:singing_recap_movie_batch_failure,
                            singing_recap_movie_batch_execution: execution,
                            customer: customer,
                            error_class: "FFmpegError")
        end
      end

      it "error_class 別の件数を返すこと" do
        expect(error_analysis["Open3::Timeout"]).to eq(3)
        expect(error_analysis["FFmpegError"]).to eq(2)
      end

      it "件数降順で返すこと" do
        keys = error_analysis.keys
        expect(keys.first).to eq("Open3::Timeout")
      end
    end
  end

  describe "#build_open_failures" do
    subject(:open_failures) { result[:open_failures] }

    context "pending / retry_failed の failure が存在する場合" do
      let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin) }

      let!(:pending_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer,
                          retry_status: "pending")
      end
      let!(:retry_failed_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure, :retry_failed,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer)
      end
      let!(:resolved_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure, :resolved,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer)
      end

      it "pending と retry_failed のみを返すこと" do
        ids = open_failures.map(&:id)
        expect(ids).to include(pending_failure.id, retry_failed_failure.id)
        expect(ids).not_to include(resolved_failure.id)
      end

      it "customer を eager load していること" do
        expect(open_failures.first.association(:customer).loaded?).to be(true)
      end
    end
  end

  describe "#build_auto_retry_summary" do
    subject(:auto_retry_summary) { result[:auto_retry_summary] }

    let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin) }

    it "必要なキーを全て返すこと" do
      expect(auto_retry_summary.keys).to contain_exactly(
        :scheduled, :running, :exhausted, :due_now, :next_due_at, :avg_attempts
      )
    end

    context "auto retry failure が存在しない場合" do
      it "scheduled が 0 であること" do
        expect(auto_retry_summary[:scheduled]).to eq(0)
      end

      it "avg_attempts が nil であること" do
        expect(auto_retry_summary[:avg_attempts]).to be_nil
      end
    end

    context "scheduled / running / exhausted が混在する場合" do
      before do
        FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_scheduled,
                          singing_recap_movie_batch_execution: execution, customer: customer,
                          auto_retry_attempts_count: 1)
        FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_running,
                          singing_recap_movie_batch_execution: execution, customer: customer,
                          auto_retry_attempts_count: 2)
        FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_exhausted,
                          singing_recap_movie_batch_execution: execution, customer: customer,
                          auto_retry_attempts_count: 3)
      end

      it "scheduled カウントが正しいこと" do
        expect(auto_retry_summary[:scheduled]).to eq(1)
      end

      it "running カウントが正しいこと" do
        expect(auto_retry_summary[:running]).to eq(1)
      end

      it "exhausted カウントが正しいこと" do
        expect(auto_retry_summary[:exhausted]).to eq(1)
      end

      it "avg_attempts が平均試行回数を返すこと" do
        expect(auto_retry_summary[:avg_attempts]).to eq(2.0)
      end
    end

    context "due_now の failure が存在する場合" do
      before do
        FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_due,
                          singing_recap_movie_batch_execution: execution, customer: customer)
      end

      it "due_now カウントが 1 であること" do
        expect(auto_retry_summary[:due_now]).to eq(1)
      end
    end
  end

  describe "#build_auto_retry_failures" do
    subject(:auto_retry_failures) { result[:auto_retry_failures] }

    let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin) }

    context "auto retry failure が存在しない場合" do
      it "空の結果を返すこと" do
        expect(auto_retry_failures).to be_empty
      end
    end

    context "scheduled / exhausted / not_applicable が混在する場合" do
      let!(:scheduled_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_scheduled,
                          singing_recap_movie_batch_execution: execution, customer: customer)
      end
      let!(:exhausted_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_exhausted,
                          singing_recap_movie_batch_execution: execution, customer: customer)
      end
      let!(:not_applicable_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure,
                          singing_recap_movie_batch_execution: execution, customer: customer,
                          auto_retry_status: "not_applicable")
      end

      it "not_applicable を除外すること" do
        ids = auto_retry_failures.map(&:id)
        expect(ids).to include(scheduled_failure.id, exhausted_failure.id)
        expect(ids).not_to include(not_applicable_failure.id)
      end

      it "customer を eager load していること" do
        expect(auto_retry_failures.first.association(:customer).loaded?).to be(true)
      end
    end

    context "auto_retry_filter: 'exhausted' を指定した場合" do
      subject(:filtered_result) { described_class.call(auto_retry_filter: "exhausted") }

      let!(:scheduled_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_scheduled,
                          singing_recap_movie_batch_execution: execution, customer: customer)
      end
      let!(:exhausted_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_exhausted,
                          singing_recap_movie_batch_execution: execution, customer: customer)
      end

      it "exhausted のみを返すこと" do
        ids = filtered_result[:auto_retry_failures].map(&:id)
        expect(ids).to include(exhausted_failure.id)
        expect(ids).not_to include(scheduled_failure.id)
      end
    end

    context "auto_retry_filter: 'due_now' を指定した場合" do
      subject(:filtered_result) { described_class.call(auto_retry_filter: "due_now") }

      let!(:due_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_due,
                          singing_recap_movie_batch_execution: execution, customer: customer)
      end
      let!(:future_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_scheduled,
                          singing_recap_movie_batch_execution: execution, customer: customer,
                          next_auto_retry_at: 10.minutes.from_now)
      end

      it "次回実行時刻が過去の scheduled のみを返すこと" do
        ids = filtered_result[:auto_retry_failures].map(&:id)
        expect(ids).to include(due_failure.id)
        expect(ids).not_to include(future_failure.id)
      end
    end

    context "不正な auto_retry_filter を指定した場合" do
      subject(:filtered_result) { described_class.call(auto_retry_filter: "invalid_filter") }

      let!(:scheduled_failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure, :auto_retry_scheduled,
                          singing_recap_movie_batch_execution: execution, customer: customer)
      end

      it "フィルターを無視して全件返すこと" do
        ids = filtered_result[:auto_retry_failures].map(&:id)
        expect(ids).to include(scheduled_failure.id)
      end
    end
  end

  describe "#build_slow_batches" do
    subject(:slow_batches) { result[:slow_batches] }

    context "started_at / finished_at が設定されたバッチがある場合" do
      let!(:fast_batch) do
        FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin,
                          started_at: 10.minutes.ago, finished_at: 9.minutes.ago)
      end
      let!(:slow_batch) do
        FactoryBot.create(:singing_recap_movie_batch_execution, :completed, admin: admin,
                          started_at: 60.minutes.ago, finished_at: 30.minutes.ago)
      end

      it "実行時間の長い順に返すこと" do
        expect(slow_batches.first.id).to eq(slow_batch.id)
      end

      it "最大10件を返すこと" do
        expect(slow_batches.size).to be <= 10
      end
    end

    context "started_at / finished_at が nil のバッチは除外すること" do
      before do
        FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin,
                          started_at: nil, finished_at: nil)
      end

      it "空配列を返すこと" do
        expect(slow_batches).to be_empty
      end
    end
  end
end
