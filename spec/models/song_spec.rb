require 'rails_helper'

RSpec.describe Song, type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { FactoryBot.create(:song, event: event) }

  describe 'バリデーションのテスト' do
    context 'songテーブルのカラムが不正' do
      it 'song_nameカラムが空欄でないこと' do
        song.song_name = ''
        expect(song.valid?).to eq false
      end
    end

    context 'chord_sheet_url' do
      it 'nilなら有効であること' do
        song.chord_sheet_url = nil
        expect(song.valid?).to eq true
      end

      it '空欄なら有効であること' do
        song.chord_sheet_url = ''
        expect(song.valid?).to eq true
      end

      it '2048文字以内なら有効であること' do
        base = 'https://example.com/'
        song.chord_sheet_url = base + ('a' * (2048 - base.length))
        expect(song.chord_sheet_url.length).to eq 2048
        expect(song.valid?).to eq true
      end

      it '2049文字なら無効であること' do
        base = 'https://example.com/'
        song.chord_sheet_url = base + ('a' * (2049 - base.length))
        expect(song.chord_sheet_url.length).to eq 2049
        expect(song.valid?).to eq false
      end

      it 'URL形式でない文字列でも、長さ以内なら有効であること' do
        song.chord_sheet_url = 'これはURLではない文字列です'
        expect(song.valid?).to eq true
      end
    end

    context 'musical_key' do
      it '空欄なら有効であること' do
        song.musical_key = ''
        expect(song.valid?).to eq true
      end

      it '"G"のような候補値が有効であること' do
        song.musical_key = 'G'
        expect(song.valid?).to eq true
      end

      it '"Am"のような候補値が有効であること' do
        song.musical_key = 'Am'
        expect(song.valid?).to eq true
      end

      it '候補外の自由入力"原曲:G→演奏:A"も有効であること' do
        song.musical_key = '原曲:G→演奏:A'
        expect(song.valid?).to eq true
      end

      it '100文字なら有効であること' do
        song.musical_key = 'a' * 100
        expect(song.valid?).to eq true
      end

      it '101文字なら無効であること' do
        song.musical_key = 'a' * 101
        expect(song.valid?).to eq false
      end
    end

    context 'capo' do
      it 'nilなら有効であること' do
        song.capo = nil
        expect(song.valid?).to eq true
      end

      it '0なら有効であること' do
        song.capo = 0
        expect(song.valid?).to eq true
      end

      it '1なら有効であること' do
        song.capo = 1
        expect(song.valid?).to eq true
      end

      it '12なら有効であること' do
        song.capo = 12
        expect(song.valid?).to eq true
      end

      it '-1なら無効であること' do
        song.capo = -1
        expect(song.valid?).to eq false
      end

      it '13なら無効であること' do
        song.capo = 13
        expect(song.valid?).to eq false
      end

      it '小数なら無効であること' do
        song.capo = 1.5
        expect(song.valid?).to eq false
      end

      it '数値でない文字列なら無効であること' do
        song.capo = 'abc'
        expect(song.valid?).to eq false
      end
    end

    context 'chord_sheet_note' do
      it '空欄なら有効であること' do
        song.chord_sheet_note = ''
        expect(song.valid?).to eq true
      end

      it '300文字なら有効であること' do
        song.chord_sheet_note = 'a' * 300
        expect(song.valid?).to eq true
      end

      it '301文字なら無効であること' do
        song.chord_sheet_note = 'a' * 301
        expect(song.valid?).to eq false
      end
    end
  end
  describe 'アソシエーションのテスト' do
    context 'Eventモデルとの関係' do
      it 'eventとN:1となっている' do
        expect(Song.reflect_on_association(:event).macro).to eq :belongs_to
      end
    end
    context 'customerモデルとの関係' do
      it 'customerモデルと1:Nとなっている' do
        expect(Song.reflect_on_association(:customers).macro).to eq :has_many
      end
      it '中間テーブルsong_customersと1:Nとなっている' do
        expect(Song.reflect_on_association(:song_customers).macro).to eq :has_many
      end
    end
    context 'JoinPartモデルとの関係' do
      it 'join_partと1:Nとなっている' do
        expect(Song.reflect_on_association(:join_parts).macro).to eq :has_many
      end
    end
  end

  describe '#recruiting_join_parts' do
    it '参加者が0人のパートのみを返すこと' do
      empty_part = FactoryBot.create(:join_part, song: song, join_part_name: 'ギター')
      filled_part = FactoryBot.create(:join_part, song: song, join_part_name: 'ベース')
      FactoryBot.create(:join_part_customer, join_part: filled_part, customer: other_customer)

      expect(song.recruiting_join_parts).to eq [empty_part]
    end

    it '全パートに参加者がいる場合は空配列を返すこと' do
      part = FactoryBot.create(:join_part, song: song, join_part_name: 'ボーカル')
      FactoryBot.create(:join_part_customer, join_part: part, customer: other_customer)

      expect(song.recruiting_join_parts).to eq []
    end

    it 'パートが存在しない場合は空配列を返すこと' do
      expect(song.recruiting_join_parts).to eq []
    end
  end

  describe '#capo_label' do
    it 'capoがnilの場合はnilを返すこと' do
      song.capo = nil
      expect(song.capo_label).to eq nil
    end

    it 'capoが0の場合は"なし"を返すこと' do
      song.capo = 0
      expect(song.capo_label).to eq 'なし'
    end

    it 'capoが1の場合は"1"を返すこと' do
      song.capo = 1
      expect(song.capo_label).to eq '1'
    end

    it 'capoが12の場合は"12"を返すこと' do
      song.capo = 12
      expect(song.capo_label).to eq '12'
    end
  end
end
