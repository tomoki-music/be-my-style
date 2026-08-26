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
  end
end
