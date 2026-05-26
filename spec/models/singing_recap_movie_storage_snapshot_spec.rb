require "rails_helper"

RSpec.describe SingingRecapMovieStorageSnapshot do
  describe "バリデーション" do
    it "有効なスナップショットが保存できること" do
      snap = build(:singing_recap_movie_storage_snapshot)
      expect(snap).to be_valid
    end

    it "snapshot_date がなければ無効であること" do
      snap = build(:singing_recap_movie_storage_snapshot, snapshot_date: nil)
      expect(snap).not_to be_valid
      expect(snap.errors[:snapshot_date]).to be_present
    end

    it "同一日付のスナップショットは2件目が無効であること" do
      create(:singing_recap_movie_storage_snapshot, snapshot_date: Date.today)
      dup = build(:singing_recap_movie_storage_snapshot, snapshot_date: Date.today)
      expect(dup).not_to be_valid
      expect(dup.errors[:snapshot_date]).to be_present
    end

    it "attached_movie_count が負値なら無効であること" do
      snap = build(:singing_recap_movie_storage_snapshot, attached_movie_count: -1)
      expect(snap).not_to be_valid
    end

    it "total_bytes が負値なら無効であること" do
      snap = build(:singing_recap_movie_storage_snapshot, total_bytes: -1)
      expect(snap).not_to be_valid
    end
  end

  describe "scope" do
    describe ".recent" do
      it "指定日数以内のスナップショットだけを返すこと" do
        create(:singing_recap_movie_storage_snapshot, snapshot_date: 5.days.ago.to_date)
        create(:singing_recap_movie_storage_snapshot, snapshot_date: 40.days.ago.to_date)

        expect(described_class.recent(7).count).to eq(1)
      end
    end

    describe ".ordered" do
      it "snapshot_date の降順で返すこと" do
        create(:singing_recap_movie_storage_snapshot, snapshot_date: 3.days.ago.to_date)
        create(:singing_recap_movie_storage_snapshot, snapshot_date: 1.day.ago.to_date)

        dates = described_class.ordered.map(&:snapshot_date)
        expect(dates).to eq(dates.sort.reverse)
      end
    end

    describe ".ascending" do
      it "snapshot_date の昇順で返すこと" do
        create(:singing_recap_movie_storage_snapshot, snapshot_date: 3.days.ago.to_date)
        create(:singing_recap_movie_storage_snapshot, snapshot_date: 1.day.ago.to_date)

        dates = described_class.ascending.map(&:snapshot_date)
        expect(dates).to eq(dates.sort)
      end
    end
  end

  describe "#total_gb" do
    it "total_bytes を GB に換算すること" do
      snap = build(:singing_recap_movie_storage_snapshot,
                   total_bytes: Singing::RecapMovieStorageMetricsService::BYTES_PER_GB.to_i)
      expect(snap.total_gb).to be_within(0.001).of(1.0)
    end

    it "total_bytes が 0 なら 0 を返すこと" do
      snap = build(:singing_recap_movie_storage_snapshot, total_bytes: 0)
      expect(snap.total_gb).to eq(0.0)
    end
  end
end
