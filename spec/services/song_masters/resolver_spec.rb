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
