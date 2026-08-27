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

  def run_dry_run
    ENV["DRY_RUN"] = "true"
    run_task
  ensure
    ENV.delete("DRY_RUN")
  end

  # Eventはsongs presenceバリデーションがあるため、:event_with_songsトレイトで1曲を持たせる。
  let(:event) { FactoryBot.create(:event, :event_with_songs) }

  # Songをsong_master_id未設定の状態で用意する。
  # (create時のassign_song_masterコールバックでSongMasterが作られるため、リンクだけ外す)
  def create_unlinked_song(song_name:, artist_name: nil)
    song = FactoryBot.create(:song, event: event, song_name: song_name, artist_name: artist_name)
    song.update_column(:song_master_id, nil)
    song
  end

  describe "DRY_RUN=true" do
    it "SongMasterを新規作成しないこと(件数が変化しない)" do
      create_unlinked_song(song_name: "DryRun新曲", artist_name: "DryRunアーティスト")
      # 解決先のSongMasterを消し、「新規作成が必要」な状態を作る
      SongMaster.where(normalized_song_name: SongMasters::Resolver.normalize("DryRun新曲")).delete_all

      expect { run_dry_run }.not_to change(SongMaster, :count)
    end

    it "Songのsong_master_idを更新しないこと" do
      song = create_unlinked_song(song_name: "DryRunリンク曲", artist_name: "アーティスト")

      expect { run_dry_run }.not_to change { song.reload.song_master_id }.from(nil)
    end

    it "孤立SongMasterを削除しないこと" do
      orphan = FactoryBot.create(:song_master, song_name: "孤立マスター", artist_name: "誰か")

      expect { run_dry_run }.not_to change { SongMaster.exists?(orphan.id) }.from(true)
    end

    it "既存SongMasterを更新しないこと" do
      master = FactoryBot.create(:song_master, song_name: "既存マスター", artist_name: "アーティスト")
      create_unlinked_song(song_name: "既存マスター", artist_name: "アーティスト")

      expect { run_dry_run }.not_to change { master.reload.updated_at }
    end
  end

  describe "通常実行" do
    it "現在のResolver解決先(正しいSongMaster)へ再リンクすること" do
      canonical = SongMasters::Resolver.call(song_name: "再リンク曲", artist_name: "再リンクP")
      wrong = FactoryBot.create(
        :song_master,
        song_name: "再リンク曲（再リンクP）",
        normalize: false,
        normalized_song_name: SongMasters::Resolver.normalize("再リンク曲（再リンクP）"),
        normalized_artist_name: ""
      )
      song = FactoryBot.create(:song, event: event, song_name: "再リンク曲（再リンクP）", artist_name: nil)
      song.update_column(:song_master_id, wrong.id)

      run_task

      expect(song.reload.song_master_id).to eq(canonical.id)
    end

    it "再実行しても結果が変わらないこと(冪等)" do
      song = create_unlinked_song(song_name: "冪等曲", artist_name: "冪等P")

      run_task
      first_master_id = song.reload.song_master_id
      expect(first_master_id).to be_present

      expect { run_task }.not_to change { song.reload.song_master_id }
      expect { run_task }.not_to change(SongMaster, :count)
    end

    it "既にsong_master_idが正しいSongは更新しないこと" do
      song = FactoryBot.create(:song, event: event, song_name: "既紐付け曲", artist_name: "アーティスト")
      original = song.song_master_id
      expect(original).to be_present

      expect { run_task }.not_to change { song.reload.song_master_id }
    end

    it "再リンク成功後、参照が無くなったSongMasterを削除すること" do
      wrong = FactoryBot.create(
        :song_master,
        song_name: "削除対象（P）",
        normalize: false,
        normalized_song_name: SongMasters::Resolver.normalize("削除対象（P）"),
        normalized_artist_name: ""
      )
      song = FactoryBot.create(:song, event: event, song_name: "削除対象（P）", artist_name: nil)
      song.update_column(:song_master_id, wrong.id)

      run_task

      expect(SongMaster.exists?(wrong.id)).to be(false)
      expect(song.reload.song_master).to be_present
    end

    it "customer_song_partsから参照されているSongMasterは削除しないこと" do
      referenced = FactoryBot.create(:song_master, song_name: "参照ありマスター", artist_name: "P")
      FactoryBot.create(:customer_song_part, song: nil, song_master: referenced, part_name: "Vocal")

      run_task

      expect(SongMaster.exists?(referenced.id)).to be(true)
    end
  end

  describe "名寄せの正しさ" do
    it "「曲名（アーティスト名）」表記と曲名＋アーティスト欄が同一SongMasterへ寄ること" do
      embedded = create_unlinked_song(song_name: "つよがり（ヨルシカ）", artist_name: nil)
      split = create_unlinked_song(song_name: "つよがり", artist_name: "ヨルシカ")

      run_task

      expect(embedded.reload.song_master_id).to eq(split.reload.song_master_id)
      expect(embedded.song_master.song_name).to eq("つよがり")
      expect(embedded.song_master.artist_name).to eq("ヨルシカ")
    end

    it "アーティスト欄が入力済みなら曲名の括弧を分解せず、別曲を誤統合しないこと" do
      plain = create_unlinked_song(song_name: "接吻", artist_name: "オリジナル・ラヴ")
      paren_in_title = create_unlinked_song(song_name: "接吻（Live）", artist_name: "オリジナル・ラヴ")

      run_task

      expect(paren_in_title.reload.song_master_id).not_to eq(plain.reload.song_master_id)
    end
  end

  describe "失敗時の安全性" do
    it "再リンク途中の例外でトランザクションごとロールバックすること" do
      song1 = create_unlinked_song(song_name: "ロールバック曲1", artist_name: "P1")
      song2 = create_unlinked_song(song_name: "ロールバック曲2", artist_name: "P2")

      call_count = 0
      allow(SongMasters::Resolver).to receive(:call).and_wrap_original do |original, **kwargs|
        call_count += 1
        raise "boom" if call_count == 2

        original.call(**kwargs)
      end

      expect { run_task }.to raise_error("boom")
      expect(song1.reload.song_master_id).to be_nil
      expect(song2.reload.song_master_id).to be_nil
    end
  end
end
