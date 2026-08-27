require 'rails_helper'

RSpec.describe SongMasters::Resolver, type: :model do
  describe '.normalize' do
    it '全角英数字を半角に正規化すること' do
      expect(described_class.normalize('Ａｍａｚｉｎｇ')).to eq described_class.normalize('Amazing')
    end

    it '大文字小文字のゆれを吸収すること' do
      expect(described_class.normalize('AMAZING')).to eq described_class.normalize('amazing')
    end

    it '空白のゆれを吸収すること' do
      expect(described_class.normalize('Amazing Grace')).to eq described_class.normalize('Amazing  Grace')
    end

    it '空文字・nilは空文字として扱うこと' do
      expect(described_class.normalize(nil)).to eq ''
      expect(described_class.normalize('')).to eq ''
    end

    it '全角スペースを半角スペースと同じものとして吸収すること' do
      expect(described_class.normalize("Amazing　Grace")).to eq described_class.normalize("Amazing Grace")
    end

    it '前後の空白を除去すること' do
      expect(described_class.normalize("  Amazing Grace  ")).to eq described_class.normalize("Amazing Grace")
    end

    it 'カーブクォート(スマートクォート)のアポストロフィを直立引用符と同一視すること' do
      expect(described_class.normalize("Rock’n’Roll")).to eq described_class.normalize("Rock'n'Roll")
    end

    it 'カーブクォートのダブルクォートを直立引用符と同一視すること' do
      expect(described_class.normalize("“Hello”")).to eq described_class.normalize('"Hello"')
    end

    it '丸の内と丸ノ内は自動的に同一視しないこと(意味的な表記ゆれは対象外)' do
      expect(described_class.normalize("丸の内")).not_to eq described_class.normalize("丸ノ内")
    end
  end

  describe '.call' do
    it '新しい曲名・アーティスト名ならSongMasterを新規作成すること' do
      expect {
        described_class.call(song_name: '新曲A', artist_name: 'アーティストA')
      }.to change(SongMaster, :count).by(1)
    end

    it '表記ゆれのある同じ曲名・アーティスト名なら既存のSongMasterを返すこと' do
      first = described_class.call(song_name: 'Amazing Grace', artist_name: 'Artist X')

      expect {
        second = described_class.call(song_name: 'ａｍａｚｉｎｇ ｇｒａｃｅ', artist_name: 'ARTIST X')
        expect(second.id).to eq first.id
      }.not_to change(SongMaster, :count)
    end

    it '曲名が同じでもアーティスト名が異なれば別のSongMasterになること' do
      first = described_class.call(song_name: '同名の曲', artist_name: 'アーティストA')
      second = described_class.call(song_name: '同名の曲', artist_name: 'アーティストB')

      expect(first.id).not_to eq second.id
    end

    it '曲名が空欄ならnilを返すこと' do
      expect(described_class.call(song_name: '', artist_name: 'アーティストA')).to be_nil
    end

    it 'アーティスト名が未設定でも曲名だけでSongMasterを作成できること' do
      master = described_class.call(song_name: 'アーティスト未設定の曲', artist_name: nil)
      expect(master).to be_present
      expect(master.normalized_artist_name).to eq ''
    end

    it 'カーブクォートと直立引用符の表記ゆれがあっても同じSongMasterに集約されること' do
      first = described_class.call(song_name: "Rock’n’Roll", artist_name: "Artist Y")

      expect {
        second = described_class.call(song_name: "Rock'n'Roll", artist_name: "Artist Y")
        expect(second.id).to eq first.id
      }.not_to change(SongMaster, :count)
    end

    describe '曲名に「（アーティスト名）」を含み、アーティスト名欄が空のケースの名寄せ' do
      # 括弧内をアーティスト名として切り出すのは「安全性が高い」場合だけ:
      #   - 括弧内が告知・募集・キー等の付随情報でない
      #   - 「曲名」+「そのアーティスト名」を裏付ける既存データ(SongMaster等)がある
      # 裏付けの無い曖昧なケースは分解せず、括弧込みの曲名を1曲として扱う。

      context '「曲名」+「アーティスト名」の裏付けが既にある場合' do
        it '「曲名（アーティスト名）」(アーティスト欄空) を、対応する 「曲名」+アーティスト欄 の既存SongMasterへ寄せること' do
          split = described_class.call(song_name: "マリーゴールド", artist_name: "あいみょん")

          expect {
            embedded = described_class.call(song_name: "マリーゴールド（あいみょん）", artist_name: nil)
            expect(embedded.id).to eq(split.id)
          }.not_to change(SongMaster, :count)
        end

        it '半角括弧「曲名(アーティスト名)」でも同様に名寄せすること' do
          split = described_class.call(song_name: "マリーゴールド", artist_name: "あいみょん")
          embedded = described_class.call(song_name: "マリーゴールド(あいみょん)", artist_name: "")

          expect(embedded.id).to eq(split.id)
        end

        it '括弧前後の空白ゆれがあっても名寄せすること' do
          split = described_class.call(song_name: "マリーゴールド", artist_name: "あいみょん")
          embedded = described_class.call(song_name: "マリーゴールド （あいみょん）", artist_name: nil)

          expect(embedded.id).to eq(split.id)
        end
      end

      context '裏付けが無い場合(曖昧)' do
        it '「曲名（アーティスト名）」を勝手に分解せず、括弧込みの曲名として別SongMasterを作ること' do
          embedded = described_class.call(song_name: "マリーゴールド（あいみょん）", artist_name: nil)

          expect(embedded.normalized_song_name).to eq(described_class.normalize("マリーゴールド（あいみょん）"))
          expect(embedded.normalized_artist_name).to eq("")
        end

        it '後から「曲名」+アーティスト欄が登録されても、既存の括弧込みSongMasterは自動統合しないこと' do
          embedded = described_class.call(song_name: "マリーゴールド（あいみょん）", artist_name: nil)
          split = described_class.call(song_name: "マリーゴールド", artist_name: "あいみょん")

          expect(embedded.id).not_to eq(split.id)
        end
      end

      context '括弧内が告知・募集・キー・バージョン等の付随情報の場合' do
        before do
          # 「曲名」+「その文字列」を裏付けるデータをあえて用意しても、付随情報は切り出さない。
          described_class.call(song_name: "ホームタウン", artist_name: "コラボイベント前祝曲!!")
          described_class.call(song_name: "ホームタウン", artist_name: "キー変更")
          described_class.call(song_name: "ホームタウン", artist_name: "募集中")
          described_class.call(song_name: "ホームタウン", artist_name: "Acoustic ver.")
        end

        it '告知文言(「コラボイベント前祝曲!!」)はアーティスト名として抽出しないこと' do
          master = described_class.call(song_name: "ホームタウン（コラボイベント前祝曲!!）", artist_name: nil)

          expect(master.normalized_artist_name).to eq("")
          expect(master.normalized_song_name).to eq(described_class.normalize("ホームタウン（コラボイベント前祝曲!!）"))
        end

        it 'キー情報(「キー変更」)はアーティスト名として抽出しないこと' do
          master = described_class.call(song_name: "ホームタウン（キー変更）", artist_name: nil)

          expect(master.normalized_artist_name).to eq("")
        end

        it '募集情報(「募集中」)はアーティスト名として抽出しないこと' do
          master = described_class.call(song_name: "ホームタウン（募集中）", artist_name: nil)

          expect(master.normalized_artist_name).to eq("")
        end

        it 'バージョン情報(「Acoustic ver.」)はアーティスト名として抽出しないこと' do
          master = described_class.call(song_name: "ホームタウン（Acoustic ver.）", artist_name: nil)

          expect(master.normalized_artist_name).to eq("")
        end
      end

      it 'アーティスト名欄が入力済みなら曲名の括弧は分解しないこと(feat.等の既存挙動を維持)' do
        with_paren = described_class.call(song_name: "曲名（東京）", artist_name: "アーティスト")
        plain = described_class.call(song_name: "曲名", artist_name: "アーティスト")

        expect(with_paren.id).not_to eq(plain.id)
      end

      it 'アーティスト名欄が入力済みなら、括弧内の値でアーティスト名を上書きしないこと' do
        master = described_class.call(song_name: "曲名（Live）", artist_name: "正しいアーティスト")

        expect(master.artist_name).to eq("正しいアーティスト")
        expect(master.normalized_artist_name).to eq(described_class.normalize("正しいアーティスト"))
      end

      it '曲名自体に括弧を含む正式タイトルを壊さないこと' do
        # 裏付けが無いので分解されず、括弧込みのタイトルがそのままキーになる。
        master = described_class.call(song_name: "Q（キュー）", artist_name: nil)

        expect(master.song_name).to eq("Q（キュー）")
        expect(master.normalized_song_name).to eq(described_class.normalize("Q（キュー）"))
        expect(master.normalized_artist_name).to eq("")
      end

      it '括弧の前に曲名が無い場合は分解せず、そのまま扱うこと' do
        master = described_class.call(song_name: "（あいみょん）", artist_name: nil)

        expect(master.normalized_artist_name).to eq("")
      end

      describe '実データ相当(Song #3・#4「羊文学 - more than words（コラボイベント前祝曲!!）」)' do
        let(:song_name) { "羊文学 - more than words（コラボイベント前祝曲!!）" }

        it '「コラボイベント前祝曲!!」をアーティスト名として切り出さないこと' do
          identity = described_class.identity_for(song_name: song_name, artist_name: nil)

          expect(identity.normalized_artist_name).to eq("")
          expect(identity.normalized_song_name).to eq(described_class.normalize(song_name))
        end

        it '括弧込みの曲名で既に存在するSongMasterへ解決し、新規作成しないこと' do
          existing = FactoryBot.create(
            :song_master,
            song_name: song_name,
            normalize: false,
            normalized_song_name: described_class.normalize(song_name),
            normalized_artist_name: ""
          )

          expect {
            resolved = described_class.call(song_name: song_name, artist_name: nil)
            expect(resolved.id).to eq(existing.id)
          }.not_to change(SongMaster, :count)
        end
      end
    end

    describe '意味的な表記ゆれは自動で同一視しないこと(誤統合防止)' do
      it '丸の内と丸ノ内は別のSongMasterになること' do
        first = described_class.call(song_name: "丸の内サディスティック", artist_name: "アーティスト")
        second = described_class.call(song_name: "丸ノ内サディスティック", artist_name: "アーティスト")

        expect(first.id).not_to eq second.id
      end

      it '略称と正式名称は別のSongMasterになること' do
        first = described_class.call(song_name: "宇宙戦艦ヤマト", artist_name: "アーティスト")
        second = described_class.call(song_name: "ヤマト", artist_name: "アーティスト")

        expect(first.id).not_to eq second.id
      end

      it 'feat.表記の有無で別のSongMasterになること' do
        first = described_class.call(song_name: "曲名 feat. ゲスト", artist_name: "アーティスト")
        second = described_class.call(song_name: "曲名", artist_name: "アーティスト")

        expect(first.id).not_to eq second.id
      end
    end
  end
end
