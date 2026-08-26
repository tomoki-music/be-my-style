require 'rails_helper'

RSpec.describe SongMaster, type: :model do
  describe 'バリデーション' do
    it '正常に登録できること' do
      song_master = FactoryBot.build(:song_master)
      expect(song_master).to be_valid
    end

    it 'song_nameが空欄なら無効であること' do
      song_master = FactoryBot.build(:song_master, song_name: '')
      expect(song_master).to be_invalid
    end

    it 'normalized_song_nameが空欄なら無効であること' do
      song_master = FactoryBot.build(:song_master, normalize: false, normalized_song_name: '')
      expect(song_master).to be_invalid
    end
  end

  describe 'UNIQUE制約' do
    it '同じnormalized_song_name・normalized_artist_nameの組み合わせは重複登録できないこと' do
      FactoryBot.create(:song_master, normalize: false, normalized_song_name: 'sametitle', normalized_artist_name: 'sameartist')
      duplicate = FactoryBot.build(:song_master, normalize: false, normalized_song_name: 'sametitle', normalized_artist_name: 'sameartist')

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'アーティスト名未設定同士(空文字)は重複登録できないこと' do
      FactoryBot.create(:song_master, normalize: false, normalized_song_name: 'notitleartist', normalized_artist_name: '')
      duplicate = FactoryBot.build(:song_master, normalize: false, normalized_song_name: 'notitleartist', normalized_artist_name: '')

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
