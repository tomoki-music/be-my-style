require 'rails_helper'

RSpec.describe SongPerformance, type: :model do
  let(:customer) { FactoryBot.create(:customer) }
  let(:event) { FactoryBot.create(:event, :event_with_songs) }
  let(:song) { FactoryBot.create(:song, event: event) }
  let(:join_part) { FactoryBot.create(:join_part, song: song, join_part_name: "Vocal") }

  def build_performance(**attrs)
    FactoryBot.build(
      :song_performance,
      customer: customer,
      song: song,
      song_master: song.song_master,
      event: event,
      join_part: join_part,
      part_name: "Vocal",
      **attrs
    )
  end

  describe '正常系' do
    it '正常に登録できること' do
      performance = build_performance
      expect(performance).to be_valid
      expect { performance.save! }.to change(SongPerformance, :count).by(1)
    end
  end

  describe '必須項目' do
    it 'customerが未設定なら無効であること' do
      performance = build_performance(customer: nil)
      expect(performance).to be_invalid
    end

    it 'song_masterが未設定なら無効であること' do
      performance = build_performance
      performance.song_master = nil
      expect(performance).to be_invalid
    end

    it 'part_nameが未設定なら無効であること' do
      performance = build_performance(part_name: nil)
      expect(performance).to be_invalid
    end

    it '不正なpart_name(候補外の値)は無効であること' do
      performance = build_performance(part_name: "でたらめなパート")
      expect(performance).to be_invalid
    end
  end

  describe 'イベント実績としての扱い(event必須)' do
    it '新規作成時にeventが未設定だと無効であること' do
      performance = build_performance(event: nil)
      expect(performance).to be_invalid
      expect(performance.errors[:event]).to be_present
    end

    it '新規作成時にsongが未設定だと無効であること' do
      performance = build_performance(song: nil)
      expect(performance).to be_invalid
    end
  end

  describe '関連の整合性' do
    it 'customer/song_master/song/event/join_partのアソシエーションが定義されていること' do
      expect(SongPerformance.reflect_on_association(:customer).macro).to eq :belongs_to
      expect(SongPerformance.reflect_on_association(:song_master).macro).to eq :belongs_to
      expect(SongPerformance.reflect_on_association(:song).macro).to eq :belongs_to
      expect(SongPerformance.reflect_on_association(:event).macro).to eq :belongs_to
      expect(SongPerformance.reflect_on_association(:join_part).macro).to eq :belongs_to
    end
  end

  describe '重複防止' do
    it '同一customer・song_master・part_name・eventの組み合わせは重複登録できないこと' do
      build_performance.save!
      duplicate = build_performance

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:customer_id]).to be_present
    end

    it '同じ曲・パートでも別イベントなら保存できること' do
      build_performance.save!

      other_event = FactoryBot.create(:event, :event_with_songs)
      other_song = FactoryBot.create(:song, event: other_event, song_name: song.song_name, artist_name: song.artist_name)
      other_join_part = FactoryBot.create(:join_part, song: other_song, join_part_name: "Vocal")

      other_performance = build_performance(event: other_event, song: other_song, join_part: other_join_part, song_master: other_song.song_master)
      expect(other_performance).to be_valid
    end

    it 'DBレベルのUNIQUE制約でも重複を防ぐこと(バリデーションを迂回した場合)' do
      build_performance.save!
      duplicate = build_performance

      expect {
        duplicate.save!(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'Song/Event/JoinPart削除時の扱い(履歴を残す)' do
    it 'Song削除後もSongPerformance自体は残り、song_idはnullifyされること' do
      performance = build_performance
      performance.save!
      song.destroy

      expect(performance.reload.song_id).to be_nil
      expect(SongPerformance.exists?(performance.id)).to eq true
    end

    it 'Event削除後もSongPerformance自体は残り、event_idはnullifyされること' do
      performance = build_performance
      performance.save!
      event_id = event.id
      event.destroy

      expect(performance.reload.event_id).to be_nil
      expect(SongPerformance.exists?(performance.id)).to eq true
      expect(Event.exists?(event_id)).to eq false
    end
  end
end
