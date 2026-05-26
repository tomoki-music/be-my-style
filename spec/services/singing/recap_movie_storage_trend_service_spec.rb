require "rails_helper"

RSpec.describe Singing::RecapMovieStorageTrendService do
  describe ".call" do
    context "スナップショットが0件の場合" do
      it "has_data が false であること" do
        result = described_class.call(days: 30)
        expect(result[:has_data]).to be false
      end

      it "snapshot_count が 0 であること" do
        result = described_class.call(days: 30)
        expect(result[:snapshot_count]).to eq(0)
      end

      it "snapshots が空配列であること" do
        result = described_class.call(days: 30)
        expect(result[:snapshots]).to be_empty
      end
    end

    context "スナップショットが1件の場合" do
      before { create(:singing_recap_movie_storage_snapshot, snapshot_date: 3.days.ago.to_date) }

      it "has_data が false であること (2件以上必要)" do
        result = described_class.call(days: 30)
        expect(result[:has_data]).to be false
      end
    end

    context "スナップショットが2件以上ある場合" do
      before do
        create(:singing_recap_movie_storage_snapshot,
               snapshot_date:  5.days.ago.to_date,
               total_bytes:    1_000_000,
               completed_bytes: 900_000,
               expired_attached_bytes: 100_000,
               estimated_monthly_cost_usd: 0.02)
        create(:singing_recap_movie_storage_snapshot,
               snapshot_date:  1.day.ago.to_date,
               total_bytes:    1_500_000,
               completed_bytes: 1_400_000,
               expired_attached_bytes: 50_000,
               estimated_monthly_cost_usd: 0.035)
      end

      subject(:result) { described_class.call(days: 30) }

      it "has_data が true であること" do
        expect(result[:has_data]).to be true
      end

      it "必要なキーを全て返すこと" do
        expect(result.keys).to contain_exactly(
          :days, :snapshot_count, :snapshots, :storage_growth,
          :cost_trend, :cleanup_effect, :has_data,
          :oldest_snapshot_at, :latest_snapshot_at,
        )
      end

      it "snapshot_count が正しいこと" do
        expect(result[:snapshot_count]).to eq(2)
      end

      describe "storage_growth" do
        subject(:growth) { result[:storage_growth] }

        it "delta_bytes が差分であること" do
          expect(growth[:delta_bytes]).to eq(500_000)
        end

        it "period_days が正の整数であること" do
          expect(growth[:period_days]).to be > 0
        end

        it "growth_pct が計算されること" do
          expect(growth[:growth_pct]).to eq(50.0)
        end
      end

      describe "cost_trend" do
        subject(:cost) { result[:cost_trend] }

        it "first_usd が最初のスナップショットのコストであること" do
          expect(cost[:first_usd]).to be_within(0.0001).of(0.02)
        end

        it "last_usd が最新のスナップショットのコストであること" do
          expect(cost[:last_usd]).to be_within(0.0001).of(0.035)
        end

        it "delta_usd が差分であること" do
          expect(cost[:delta_usd]).to be_within(0.0001).of(0.015)
        end
      end

      describe "cleanup_effect" do
        subject(:effect) { result[:cleanup_effect] }

        it "max_expired_bytes が期間内の最大値であること" do
          expect(effect[:max_expired_bytes]).to eq(100_000)
        end

        it "min_expired_bytes が期間内の最小値であること" do
          expect(effect[:min_expired_bytes]).to eq(50_000)
        end

        it "reduced_bytes が max - min であること" do
          expect(effect[:reduced_bytes]).to eq(50_000)
        end
      end

      describe "snapshots series" do
        it "昇順で並んでいること" do
          dates = result[:snapshots].map { |s| s[:date] }
          expect(dates).to eq(dates.sort)
        end

        it "各エントリに必要なキーが含まれること" do
          expect(result[:snapshots].first.keys).to include(
            :date, :attached_movie_count, :total_bytes, :total_gb,
            :completed_bytes, :expired_attached_bytes, :estimated_monthly_cost_usd
          )
        end
      end

      it "oldest_snapshot_at が最古の日付であること" do
        expect(result[:oldest_snapshot_at]).to eq(5.days.ago.to_date)
      end

      it "latest_snapshot_at が最新の日付であること" do
        expect(result[:latest_snapshot_at]).to eq(1.day.ago.to_date)
      end
    end

    context "days パラメータが期間外のスナップショットを除外すること" do
      before do
        create(:singing_recap_movie_storage_snapshot, snapshot_date: 40.days.ago.to_date, total_bytes: 1_000)
        create(:singing_recap_movie_storage_snapshot, snapshot_date: 3.days.ago.to_date,  total_bytes: 2_000)
      end

      it "days=7 では 7日以内のスナップショットだけを含むこと" do
        result = described_class.call(days: 7)
        expect(result[:snapshot_count]).to eq(1)
        expect(result[:snapshots].first[:total_bytes]).to eq(2_000)
      end
    end
  end
end
