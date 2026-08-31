require "rails_helper"
require "rake"

RSpec.describe "song_masters:merge_pairs rakeタスク" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("song_masters:merge_pairs")
  end

  around do |example|
    saved = ENV.to_hash.slice("MERGE_PAIRS", "APPLY", "CONFIRM", "DRY_RUN")
    %w[MERGE_PAIRS APPLY CONFIRM DRY_RUN].each { |key| ENV.delete(key) }
    example.run
  ensure
    %w[MERGE_PAIRS APPLY CONFIRM DRY_RUN].each { |key| ENV.delete(key) }
    saved.each { |key, value| ENV[key] = value }
  end

  def run_task
    Rake::Task["song_masters:merge_pairs"].invoke
  ensure
    Rake::Task["song_masters:merge_pairs"].reenable
  end

  # 正: 「曲名」+「アーティスト欄」で正しく登録されたSongMaster
  let!(:canonical) { SongMasters::Resolver.call(song_name: "ワタリドリ", artist_name: "[Alexandros]") }
  let(:legacy_name) { "ワタリドリ〜Alexandros〜" }
  let!(:duplicate) do
    FactoryBot.create(
      :song_master,
      song_name: legacy_name,
      normalize: false,
      normalized_song_name: SongMasters::Resolver.normalize(legacy_name),
      normalized_artist_name: ""
    )
  end

  describe "実行モードの判定" do
    it "MERGE_PAIRS が無ければ安全にエラー終了すること" do
      expect { run_task }.to raise_error(SystemExit)
    end

    it "MERGE_PAIRS だけなら DRY RUN(DB変更なし)で実行すること" do
      ENV["MERGE_PAIRS"] = "#{canonical.id}:#{duplicate.id}"
      expect { run_task }.not_to change { [SongMaster.count, SongMasterAlias.count] }
    end

    it "APPLY=true だけでは本適用しないこと(安全にエラー終了)" do
      ENV["MERGE_PAIRS"] = "#{canonical.id}:#{duplicate.id}"
      ENV["APPLY"] = "true"
      expect { run_task }.to raise_error(SystemExit)
      expect(SongMaster.exists?(duplicate.id)).to be(true)
    end

    it "CONFIRM だけでは本適用しないこと(安全にエラー終了)" do
      ENV["MERGE_PAIRS"] = "#{canonical.id}:#{duplicate.id}"
      ENV["CONFIRM"] = "MERGE_SONG_MASTERS"
      expect { run_task }.to raise_error(SystemExit)
      expect(SongMaster.exists?(duplicate.id)).to be(true)
    end

    it "APPLY=true + DRY_RUN=true の矛盾はエラーにすること" do
      ENV["MERGE_PAIRS"] = "#{canonical.id}:#{duplicate.id}"
      ENV["APPLY"] = "true"
      ENV["CONFIRM"] = "MERGE_SONG_MASTERS"
      ENV["DRY_RUN"] = "true"
      expect { run_task }.to raise_error(SystemExit)
      expect(SongMaster.exists?(duplicate.id)).to be(true)
    end

    it "APPLY=false + CONFIRM の矛盾はエラーにすること" do
      ENV["MERGE_PAIRS"] = "#{canonical.id}:#{duplicate.id}"
      ENV["APPLY"] = "false"
      ENV["CONFIRM"] = "MERGE_SONG_MASTERS"
      expect { run_task }.to raise_error(SystemExit)
    end

    it "APPLY=true と CONFIRM=MERGE_SONG_MASTERS の両方でのみ本適用すること" do
      song = FactoryBot.create(:song, event: FactoryBot.create(:event, :event_with_songs), song_name: legacy_name)
      song.update_column(:song_master_id, duplicate.id)

      ENV["MERGE_PAIRS"] = "#{canonical.id}:#{duplicate.id}"
      ENV["APPLY"] = "true"
      ENV["CONFIRM"] = "MERGE_SONG_MASTERS"

      expect { run_task }.to change { SongMaster.exists?(duplicate.id) }.from(true).to(false)
      expect(song.reload.song_master_id).to eq(canonical.id)
    end
  end

  describe "MERGE_PAIRS の検証" do
    it "不正な形式はエラーにすること" do
      ENV["MERGE_PAIRS"] = "abc:def"
      expect { run_task }.to raise_error(SystemExit)
    end

    it "余分な区切り文字はエラーにすること" do
      ENV["MERGE_PAIRS"] = "#{canonical.id}:#{duplicate.id},"
      expect { run_task }.to raise_error(SystemExit)
    end
  end
end
