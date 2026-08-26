require "rails_helper"
require "rake"

RSpec.describe "song_masters:backfill_songs rakeタスク" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("song_masters:backfill_songs")
  end

  def run_task
    Rake::Task["song_masters:backfill_songs"].invoke
  ensure
    Rake::Task["song_masters:backfill_songs"].reenable
  end

  let(:event) { FactoryBot.create(:event, :event_with_songs) }

  it "song_master_id未設定の既存Songへ、曲名・アーティスト名からSongMasterを紐付けること" do
    song = FactoryBot.create(:song, event: event, song_name: "紐付け対象曲", artist_name: "アーティスト")
    song.update_column(:song_master_id, nil)

    expect { run_task }.to change { song.reload.song_master_id }.from(nil)
    expect(song.song_master.song_name).to eq "紐付け対象曲"
  end

  it "既にsong_master_idが設定済みのSongは変更しないこと(冪等)" do
    song = FactoryBot.create(:song, event: event, song_name: "既紐付け曲", artist_name: "アーティスト")
    original_song_master_id = song.song_master_id
    expect(original_song_master_id).to be_present

    run_task

    expect(song.reload.song_master_id).to eq original_song_master_id
  end

  it "DRY_RUN=trueの場合はDBを更新しないこと" do
    song = FactoryBot.create(:song, event: event, song_name: "dry run対象曲", artist_name: "アーティスト")
    song.update_column(:song_master_id, nil)

    begin
      ENV["DRY_RUN"] = "true"
      expect { run_task }.not_to change { song.reload.song_master_id }
    ensure
      ENV.delete("DRY_RUN")
    end
  end

  it "何度実行しても同じ結果になること(冪等)" do
    song = FactoryBot.create(:song, event: event, song_name: "複数回実行対象曲", artist_name: "アーティスト")
    song.update_column(:song_master_id, nil)

    run_task
    first_song_master_id = song.reload.song_master_id

    expect { run_task }.not_to change { song.reload.song_master_id }
    expect(song.song_master_id).to eq first_song_master_id
  end
end
