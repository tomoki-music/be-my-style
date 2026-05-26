require "rails_helper"

RSpec.describe Singing::RecapMovieStorageSnapshotService do
  let(:today) { Date.current }

  describe ".call" do
    context "スナップショットが存在しない場合" do
      it "スナップショットを新規作成すること" do
        expect { described_class.call(date: today) }
          .to change(SingingRecapMovieStorageSnapshot, :count).by(1)
      end

      it "created: true を返すこと" do
        result = described_class.call(date: today)
        expect(result.created).to be true
        expect(result.skipped).to be false
      end

      it "snapshot_date が指定日付であること" do
        result = described_class.call(date: today)
        expect(result.snapshot.snapshot_date).to eq(today)
      end

      it "metrics の値が snapshot に保存されること" do
        result = described_class.call(date: today)
        snap   = result.snapshot

        expect(snap.attached_movie_count).to be_a(Integer)
        expect(snap.total_bytes).to be_a(Integer)
        expect(snap.estimated_monthly_cost_usd).to be >= 0
      end
    end

    context "同日のスナップショットが既に存在する場合" do
      before { create(:singing_recap_movie_storage_snapshot, snapshot_date: today) }

      it "新規作成しないこと" do
        expect { described_class.call(date: today) }
          .not_to change(SingingRecapMovieStorageSnapshot, :count)
      end

      it "skipped: true を返すこと" do
        result = described_class.call(date: today)
        expect(result.skipped).to be true
        expect(result.created).to be false
      end

      it "既存 snapshot を返すこと" do
        existing = SingingRecapMovieStorageSnapshot.find_by(snapshot_date: today)
        result   = described_class.call(date: today)
        expect(result.snapshot.id).to eq(existing.id)
      end
    end

    context "過去日付を指定した場合" do
      it "指定日付でスナップショットを作成すること" do
        past = 3.days.ago.to_date
        result = described_class.call(date: past)
        expect(result.snapshot.snapshot_date).to eq(past)
      end
    end
  end
end
