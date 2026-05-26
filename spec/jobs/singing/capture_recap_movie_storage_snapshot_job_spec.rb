require "rails_helper"

RSpec.describe Singing::CaptureRecapMovieStorageSnapshotJob do
  describe "#perform" do
    context "日付なしで実行する場合" do
      it "今日のスナップショットを作成すること" do
        expect {
          described_class.perform_now
        }.to change(SingingRecapMovieStorageSnapshot, :count).by(1)

        snap = SingingRecapMovieStorageSnapshot.find_by(snapshot_date: Date.current)
        expect(snap).not_to be_nil
      end
    end

    context "日付文字列を指定する場合" do
      it "指定日付のスナップショットを作成すること" do
        past = 2.days.ago.to_date
        expect {
          described_class.perform_now(past.to_s)
        }.to change(SingingRecapMovieStorageSnapshot, :count).by(1)

        snap = SingingRecapMovieStorageSnapshot.find_by(snapshot_date: past)
        expect(snap).not_to be_nil
      end
    end

    context "同日のスナップショットが既に存在する場合" do
      before { create(:singing_recap_movie_storage_snapshot, snapshot_date: Date.current) }

      it "新規作成しないこと" do
        expect {
          described_class.perform_now
        }.not_to change(SingingRecapMovieStorageSnapshot, :count)
      end
    end
  end
end
