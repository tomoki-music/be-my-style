require "rails_helper"
require "rake"

RSpec.describe "song_masters:merge_known_duplicates rakeタスク" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("song_masters:merge_known_duplicates")
  end

  def run_task
    Rake::Task["song_masters:merge_known_duplicates"].invoke
  ensure
    Rake::Task["song_masters:merge_known_duplicates"].reenable
  end

  let(:executed_calls) { [] }

  before do
    allow(SongMasters::Merge).to receive(:call) do |**kwargs|
      executed_calls << kwargs.slice(:canonical_id, :duplicate_id, :dry_run)
      SongMasters::Merge::Result.new(performed: !kwargs[:dry_run], already_merged: false, executable: true)
    end
  end

  it "監査済み6組すべてについて、統合方向(統合元 -> 正)で Merge を呼ぶこと" do
    run_task

    expect(executed_calls).to contain_exactly(
      { canonical_id: 43,  duplicate_id: 398, dry_run: false },
      { canonical_id: 93,  duplicate_id: 102, dry_run: false },
      { canonical_id: 139, duplicate_id: 162, dry_run: false },
      { canonical_id: 140, duplicate_id: 239, dry_run: false },
      { canonical_id: 176, duplicate_id: 203, dry_run: false },
      { canonical_id: 318, duplicate_id: 324, dry_run: false }
    )
  end

  it "DRY_RUN=true のとき dry_run: true で Merge を呼ぶこと" do
    ENV["DRY_RUN"] = "true"
    run_task
    expect(executed_calls).to all(include(dry_run: true))
  ensure
    ENV.delete("DRY_RUN")
  end

  it "実行不可のペアがあっても例外を投げず最後まで処理すること" do
    allow(SongMasters::Merge).to receive(:call).and_return(
      SongMasters::Merge::Result.new(performed: false, already_merged: false, executable: false, aborted_reason: "テスト")
    )

    expect { run_task }.not_to raise_error
  end
end
