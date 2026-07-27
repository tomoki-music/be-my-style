require 'rails_helper'

RSpec.describe SongTemplate, type: :model do
  let(:community) { FactoryBot.create(:community) }
  let(:customer) { FactoryBot.create(:customer) }
  let(:song_template) { FactoryBot.create(:song_template, community: community, customer: customer) }

  describe 'バリデーションのテスト' do
    context 'community' do
      it '必須であること' do
        song_template.community = nil
        expect(song_template.valid?).to eq false
      end
    end

    context 'song_name' do
      it '必須であること' do
        song_template.song_name = ''
        expect(song_template.valid?).to eq false
      end
    end

    context 'customer' do
      it 'nilでも有効であること' do
        song_template.customer = nil
        expect(song_template.valid?).to eq true
      end
    end

    context 'chord_sheet_url' do
      it 'nilなら有効であること' do
        song_template.chord_sheet_url = nil
        expect(song_template.valid?).to eq true
      end

      it '2048文字以内なら有効であること' do
        base = 'https://example.com/'
        song_template.chord_sheet_url = base + ('a' * (2048 - base.length))
        expect(song_template.chord_sheet_url.length).to eq 2048
        expect(song_template.valid?).to eq true
      end

      it '2049文字なら無効であること' do
        base = 'https://example.com/'
        song_template.chord_sheet_url = base + ('a' * (2049 - base.length))
        expect(song_template.chord_sheet_url.length).to eq 2049
        expect(song_template.valid?).to eq false
      end

      it 'URL形式でない文字列でも、長さ以内なら有効であること' do
        song_template.chord_sheet_url = 'これはURLではない文字列です'
        expect(song_template.valid?).to eq true
      end
    end

    context 'tab_sheet_url' do
      it '2048文字以内なら有効であること' do
        base = 'https://example.com/'
        song_template.tab_sheet_url = base + ('a' * (2048 - base.length))
        expect(song_template.tab_sheet_url.length).to eq 2048
        expect(song_template.valid?).to eq true
      end

      it '2049文字なら無効であること' do
        base = 'https://example.com/'
        song_template.tab_sheet_url = base + ('a' * (2049 - base.length))
        expect(song_template.tab_sheet_url.length).to eq 2049
        expect(song_template.valid?).to eq false
      end

      it 'URL形式でない文字列でも、長さ以内なら有効であること' do
        song_template.tab_sheet_url = 'これはURLではない文字列です'
        expect(song_template.valid?).to eq true
      end
    end

    context 'musical_key' do
      it '100文字なら有効であること' do
        song_template.musical_key = 'a' * 100
        expect(song_template.valid?).to eq true
      end

      it '101文字なら無効であること' do
        song_template.musical_key = 'a' * 101
        expect(song_template.valid?).to eq false
      end
    end

    context 'capo' do
      it 'nilなら有効であること' do
        song_template.capo = nil
        expect(song_template.valid?).to eq true
      end

      it '0なら有効であること' do
        song_template.capo = 0
        expect(song_template.valid?).to eq true
      end

      it '12なら有効であること' do
        song_template.capo = 12
        expect(song_template.valid?).to eq true
      end

      it '-1なら無効であること' do
        song_template.capo = -1
        expect(song_template.valid?).to eq false
      end

      it '13なら無効であること' do
        song_template.capo = 13
        expect(song_template.valid?).to eq false
      end
    end

    context 'chord_sheet_note' do
      it '300文字なら有効であること' do
        song_template.chord_sheet_note = 'a' * 300
        expect(song_template.valid?).to eq true
      end

      it '301文字なら無効であること' do
        song_template.chord_sheet_note = 'a' * 301
        expect(song_template.valid?).to eq false
      end
    end

    context '重複' do
      it '同じCommunity内で同名のテンプレートを複数作成できること' do
        FactoryBot.create(:song_template, community: community, song_name: "丸の内サディスティック", artist_name: "椎名林檎")

        duplicated = FactoryBot.build(:song_template, community: community, song_name: "丸の内サディスティック", artist_name: "椎名林檎")
        expect(duplicated.valid?).to eq true
        expect { duplicated.save! }.not_to raise_error
      end
    end
  end

  describe 'アソシエーションのテスト' do
    it 'communityとN:1となっている' do
      expect(SongTemplate.reflect_on_association(:community).macro).to eq :belongs_to
    end

    it 'customerとN:1となっている(optional)' do
      expect(SongTemplate.reflect_on_association(:customer).macro).to eq :belongs_to
    end

    it 'source_songとN:1となっている(optional)' do
      expect(SongTemplate.reflect_on_association(:source_song).macro).to eq :belongs_to
    end
  end

  describe '#copyable_attributes' do
    it 'イベント固有の情報を含まず、コピー対象の属性のみを返すこと' do
      template = FactoryBot.create(
        :song_template, :with_chord_sheet, :with_tab_sheet,
        community: community, customer: customer,
        song_name: "丸の内サディスティック", artist_name: "椎名林檎",
        youtube_url: "https://youtube.com/watch?v=xxx", introduction: "紹介文"
      )

      expect(template.copyable_attributes).to eq(
        song_name: "丸の内サディスティック",
        artist_name: "椎名林檎",
        youtube_url: "https://youtube.com/watch?v=xxx",
        introduction: "紹介文",
        chord_sheet_url: "https://example.com/chord-sheet",
        tab_sheet_url: "https://example.com/tab-sheet",
        musical_key: "G",
        capo: 2,
        chord_sheet_note: "初心者向けの簡単コード版です"
      )
    end
  end

  describe 'Song削除時の挙動' do
    it 'source_songが削除されてもテンプレート自体は残り、source_song_idがnullになること' do
      event = FactoryBot.create(:event, :event_with_songs, community: community)
      song = FactoryBot.create(:song, event: event)
      template = FactoryBot.create(:song_template, community: community, source_song: song)

      song.destroy

      expect(SongTemplate.exists?(template.id)).to eq true
      expect(template.reload.source_song_id).to be_nil
    end
  end
end
