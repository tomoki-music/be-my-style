require "rails_helper"
require "rake"

RSpec.describe "song_masters:duplicate_candidates rakeタスク" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("song_masters:duplicate_candidates")
  end

  def run_task
    Rake::Task["song_masters:duplicate_candidates"].invoke
  ensure
    Rake::Task["song_masters:duplicate_candidates"].reenable
  end

  it "データを変更しないこと(read-only)" do
    FactoryBot.create(:song_master, song_name: "重複候補曲", normalize: false, normalized_song_name: "a", normalized_artist_name: "")
    FactoryBot.create(:song_master, song_name: "重複候補曲！", normalize: false, normalized_song_name: "b", normalized_artist_name: "")

    expect { run_task }.not_to change(SongMaster, :count)
  end

  it "記号・空白違いだけの曲名を重複候補として検出すること" do
    FactoryBot.create(:song_master, song_name: "重複候補曲", normalize: false, normalized_song_name: "a", normalized_artist_name: "")
    FactoryBot.create(:song_master, song_name: "重複候補曲！", normalize: false, normalized_song_name: "b", normalized_artist_name: "")

    expect { run_task }.to output(/重複候補グループ: 1件/).to_stdout
  end

  it "重複候補がない場合はその旨を出力すること" do
    FactoryBot.create(:song_master, song_name: "唯一の曲A")
    FactoryBot.create(:song_master, song_name: "唯一の曲B")

    expect { run_task }.to output(/重複候補は見つかりませんでした/).to_stdout
  end
end
