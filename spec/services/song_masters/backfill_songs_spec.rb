require "rails_helper"

RSpec.describe SongMasters::BackfillSongs do
  let(:event) { FactoryBot.create(:event, :event_with_songs) }

  def create_unlinked_song(song_name:, artist_name: nil)
    song = FactoryBot.create(:song, event: event, song_name: song_name, artist_name: artist_name)
    song.update_column(:song_master_id, nil)
    song
  end

  describe "dry_run: true" do
    it "DBを一切変更せず、実行予定だけを返すこと" do
      # 「曲名」+「アーティスト欄」入力済みの既存SongMasterが、括弧内切り出しの裏付けになる。
      canonical = SongMasters::Resolver.call(song_name: "ドライラン曲", artist_name: "ドライランP")
      wrong = FactoryBot.create(
        :song_master,
        song_name: "ドライラン曲（ドライランP）",
        normalize: false,
        normalized_song_name: SongMasters::Resolver.normalize("ドライラン曲（ドライランP）"),
        normalized_artist_name: ""
      )
      song = FactoryBot.create(:song, event: event, song_name: "ドライラン曲（ドライランP）", artist_name: nil)
      song.update_column(:song_master_id, wrong.id)

      result = nil
      aggregate_failures do
        expect { result = described_class.call(dry_run: true) }.not_to change(SongMaster, :count)
        expect(song.reload.song_master_id).to eq(wrong.id)
        expect(SongMaster.exists?(wrong.id)).to be(true)
      end

      expect(result.relink_count).to eq(1)
      expect(result.orphans.map(&:song_master_id)).to contain_exactly(wrong.id)
      # 再リンク先の正しいSongMasterは削除候補に含めない
      expect(result.orphans.map(&:song_master_id)).not_to include(canonical.id)
      expect(result.deleted_song_master_ids).to be_empty
    end

    it "括弧内が告知文言のSong(実データ相当: 羊文学 #3・#4)を、括弧込み曲名のまま扱い一切変更しないこと" do
      song_name = "羊文学 - more than words（コラボイベント前祝曲!!）"
      existing = FactoryBot.create(
        :song_master,
        song_name: song_name,
        normalize: false,
        normalized_song_name: SongMasters::Resolver.normalize(song_name),
        normalized_artist_name: ""
      )
      song_a = FactoryBot.create(:song, event: event, song_name: song_name, artist_name: nil)
      song_b = FactoryBot.create(:song, event: event, song_name: song_name, artist_name: nil)
      [song_a, song_b].each { |s| s.update_column(:song_master_id, nil) }

      result = nil
      aggregate_failures do
        expect { result = described_class.call(dry_run: true) }.not_to change(SongMaster, :count)
        expect(song_a.reload.song_master_id).to be_nil
        expect(song_b.reload.song_master_id).to be_nil
      end

      # 「コラボイベント前祝曲!!」というアーティスト名のSongMaster新規作成は予定に入らない
      expect(result.creates.map(&:artist_name)).not_to include("コラボイベント前祝曲!!")
      expect(result.relinks.map(&:song_id)).to contain_exactly(song_a.id, song_b.id)
      expect(result.relinks.map(&:to_song_master_id).uniq).to eq([existing.id])
      expect(result.orphans.map(&:song_master_id)).not_to include(existing.id)
    end

    it "解決先SongMasterが存在しないケースを新規作成せず、作成予定として返すこと" do
      song = create_unlinked_song(song_name: "未存在曲", artist_name: "未存在P")
      SongMaster.where(normalized_song_name: SongMasters::Resolver.normalize("未存在曲")).delete_all

      result = nil
      expect { result = described_class.call(dry_run: true) }.not_to change(SongMaster, :count)

      expect(result.creates.map(&:song_name)).to include("未存在曲")
      expect(song.reload.song_master_id).to be_nil
    end
  end

  describe "dry_run: false" do
    it "デフォルト(delete_orphans未指定)では再リンクのみ行い、孤立SongMasterを削除しないこと" do
      canonical = SongMasters::Resolver.call(song_name: "分離確認曲", artist_name: "P")
      wrong = FactoryBot.create(
        :song_master,
        song_name: "分離確認曲（P）",
        normalize: false,
        normalized_song_name: SongMasters::Resolver.normalize("分離確認曲（P）"),
        normalized_artist_name: ""
      )
      song = FactoryBot.create(:song, event: event, song_name: "分離確認曲（P）", artist_name: nil)
      song.update_column(:song_master_id, wrong.id)

      result = described_class.call(dry_run: false)

      expect(song.reload.song_master_id).to eq(canonical.id)
      expect(SongMaster.exists?(wrong.id)).to be(true)
      expect(result.deleted_song_master_ids).to be_empty
      # 削除候補としては見えているが、削除は保留されている
      expect(result.orphans.map(&:song_master_id)).to include(wrong.id)
    end

    it "delete_orphans: true のとき、トランザクション内で再リンクし、その後に孤立SongMasterを削除すること" do
      canonical = SongMasters::Resolver.call(song_name: "本実行曲", artist_name: "P")
      wrong = FactoryBot.create(
        :song_master,
        song_name: "本実行曲（P）",
        normalize: false,
        normalized_song_name: SongMasters::Resolver.normalize("本実行曲（P）"),
        normalized_artist_name: ""
      )
      song = FactoryBot.create(:song, event: event, song_name: "本実行曲（P）", artist_name: nil)
      song.update_column(:song_master_id, wrong.id)

      result = described_class.call(dry_run: false, delete_orphans: true)

      expect(song.reload.song_master_id).to eq(canonical.id)
      expect(song.reload.song_master.artist_name).to eq("P")
      expect(SongMaster.exists?(wrong.id)).to be(false)
      expect(result.deleted_song_master_ids).to include(wrong.id)
    end

    it "括弧内が告知文言のSongは分解せず、括弧込みの曲名のSongMasterへ紐付けること(実データ相当: 羊文学)" do
      song_name = "羊文学 - more than words（コラボイベント前祝曲!!）"
      existing = FactoryBot.create(
        :song_master,
        song_name: song_name,
        normalize: false,
        normalized_song_name: SongMasters::Resolver.normalize(song_name),
        normalized_artist_name: ""
      )
      song_a = FactoryBot.create(:song, event: event, song_name: song_name, artist_name: nil)
      song_b = FactoryBot.create(:song, event: event, song_name: song_name, artist_name: nil)
      [song_a, song_b].each { |s| s.update_column(:song_master_id, nil) }

      result = nil
      expect { result = described_class.call(dry_run: false) }.not_to change(SongMaster, :count)

      expect(song_a.reload.song_master_id).to eq(existing.id)
      expect(song_b.reload.song_master_id).to eq(existing.id)
      expect(result.creates).to be_empty
      expect(result.deleted_song_master_ids).not_to include(existing.id)
    end
  end

  describe "統合済み(SongMasterAlias)との整合" do
    it "統合元の旧表記Songを、新規SongMaster作成ではなく正SongMasterへ寄せること" do
      canonical = SongMasters::Resolver.call(song_name: "統合済み曲", artist_name: "統合済みP")
      legacy_name = "統合済み曲（謎表記！）"
      SongMasterAlias.create!(
        song_master: canonical,
        normalized_song_name: SongMasters::Resolver.normalize(legacy_name),
        normalized_artist_name: ""
      )
      song = create_unlinked_song(song_name: legacy_name)

      result = nil
      expect { result = described_class.call(dry_run: false) }.not_to change(SongMaster, :count)

      expect(song.reload.song_master_id).to eq(canonical.id)
      expect(result.creates).to be_empty
    end
  end

  describe "本番相当: 曲名にアーティスト名・注記が混ざった表記の名寄せ" do
    # 「マリーゴールド」+「あいみょん」が別カラムで入力されたSong(裏付け)が1件でもあれば、
    # 区切り・括弧・先頭注記で表記の揺れた同一曲を、同じ正規SongMasterへ寄せる。
    def unlinked(song_name, artist_name = nil)
      s = FactoryBot.create(:song, event: event, song_name: song_name, artist_name: artist_name)
      s.update_column(:song_master_id, nil)
      s
    end

    it "マリーゴールドの各種表記を、1つの正規SongMaster(マリーゴールド/あいみょん)へ解決すること" do
      songs = [
        unlinked("マリーゴールド", "あいみょん"), # 裏付けになる別カラム入力
        unlinked("マリーゴールド（あいみょん）"),
        unlinked("マリーゴールド(あいみょん)"),
        unlinked("マリーゴールド / あいみょん"),
        unlinked("あいみょん - マリーゴールド"),
        unlinked("あいみょん – マリーゴールド"),
        unlinked("あいみょん　—　マリーゴールド"),
        unlinked("【Key+4】あいみょん - マリーゴールド"),
        unlinked("【時間に余裕があれば】マリーゴールド（あいみょん）"),
        unlinked("【原曲キー】マリーゴールド", "あいみょん")
      ]

      result = described_class.call(dry_run: false)

      master_ids = songs.map { |s| s.reload.song_master_id }
      expect(master_ids.uniq.size).to eq(1)
      master = SongMaster.find(master_ids.first)
      expect(master.normalized_song_name).to eq(SongMasters::Resolver.normalize("マリーゴールド"))
      expect(master.normalized_artist_name).to eq(SongMasters::Resolver.normalize("あいみょん"))
      expect(result.creates.size).to eq(0)
    end

    it "裏付けが無ければ区切り表記を分解せず、意味的に別曲を統合しないこと" do
      # 「あいみょん」+「マリーゴールド」を裏付けるデータはどこにも無い。
      dash = unlinked("あいみょん - マリーゴールド")
      plain = unlinked("マリーゴールド", "あいみょん")
      # ↑ plain は「マリーゴールド」+「あいみょん」であって「あいみょん」+「マリーゴールド」ではない

      described_class.call(dry_run: false)

      # dash は裏付けの向き(曲=マリーゴールド, 歌手=あいみょん)で解決されるため plain と一致する。
      expect(dash.reload.song_master_id).to eq(plain.reload.song_master_id)
    end

    it "両向きに裏付けがある曖昧なケースは分解せず、元の文字列のまま別SongMasterにすること" do
      # 「Sound」/「Vision」の両向きを裏付けるデータを用意する。
      unlinked("Sound", "Vision")
      unlinked("Vision", "Sound")
      ambiguous = unlinked("Sound / Vision")

      described_class.call(dry_run: false)

      expect(ambiguous.reload.song_master.normalized_song_name)
        .to eq(SongMasters::Resolver.normalize("Sound / Vision"))
      expect(ambiguous.song_master.normalized_artist_name).to eq("")
    end

    it "dry-runでは上記の名寄せ予定を返すだけでDBを変更しないこと" do
      unlinked("マリーゴールド", "あいみょん")
      embedded = unlinked("あいみょん - マリーゴールド")

      result = nil
      expect { result = described_class.call(dry_run: true) }.not_to change(SongMaster, :count)
      expect(embedded.reload.song_master_id).to be_nil
      expect(result.relinks.map(&:song_id)).to include(embedded.id)
    end

    it "処理順を変えても同じSongMasterへ解決すること(冪等・順序非依存)" do
      forms = [
        ["マリーゴールド", "あいみょん"],
        ["マリーゴールド（あいみょん）", nil],
        ["あいみょん - マリーゴールド", nil],
        ["【Key+4】あいみょん - マリーゴールド", nil]
      ]
      created = forms.shuffle.map { |song_name, artist_name| unlinked(song_name, artist_name) }

      described_class.call(dry_run: false)
      first = created.map { |s| s.reload.song_master_id }

      # 再実行しても変化しない
      expect { described_class.call(dry_run: false) }
        .not_to change { created.map { |s| s.reload.song_master_id } }
      expect(first.compact.uniq.size).to eq(1)
    end
  end
end
