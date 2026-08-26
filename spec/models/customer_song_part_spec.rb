require 'rails_helper'

RSpec.describe CustomerSongPart, type: :model do
  let(:customer) { FactoryBot.create(:customer) }
  let(:event) { FactoryBot.create(:event, :event_with_songs) }
  let(:song) { FactoryBot.create(:song, event: event) }

  def build_customer_song_part(**attrs)
    FactoryBot.build(
      :customer_song_part,
      customer: customer,
      song: song,
      song_master: song.song_master,
      part_name: "Vocal",
      **attrs
    )
  end

  describe '正常系' do
    it '正常に登録できること' do
      customer_song_part = build_customer_song_part
      expect(customer_song_part).to be_valid
      expect { customer_song_part.save! }.to change(CustomerSongPart, :count).by(1)
    end
  end

  describe '必須項目' do
    it 'customerが未設定なら無効であること' do
      expect(build_customer_song_part(customer: nil)).to be_invalid
    end

    it 'song_masterが未設定なら無効であること' do
      customer_song_part = build_customer_song_part
      customer_song_part.song_master = nil
      expect(customer_song_part).to be_invalid
    end

    it '新規作成時にsongが未設定なら無効であること' do
      expect(build_customer_song_part(song: nil)).to be_invalid
    end

    it '不正なpart_name(候補外の値)は無効であること' do
      expect(build_customer_song_part(part_name: "でたらめなパート")).to be_invalid
    end
  end

  describe '関連の整合性' do
    it 'customer/song_master/songのアソシエーションが定義されていること' do
      expect(CustomerSongPart.reflect_on_association(:customer).macro).to eq :belongs_to
      expect(CustomerSongPart.reflect_on_association(:song_master).macro).to eq :belongs_to
      expect(CustomerSongPart.reflect_on_association(:song).macro).to eq :belongs_to
    end

    it 'eventの概念を持たない(自己申告であることをテーブル構造自体で区別する)' do
      expect(CustomerSongPart.column_names).not_to include("event_id")
    end
  end

  describe '自己登録の重複防止' do
    it '同一customer・song_master・part_nameの組み合わせは重複登録できないこと' do
      build_customer_song_part.save!
      duplicate = build_customer_song_part

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:customer_id]).to be_present
    end

    it '同じ曲でも別パートなら登録できること' do
      build_customer_song_part(part_name: "Vocal").save!
      other_part = build_customer_song_part(part_name: "Guitar")

      expect(other_part).to be_valid
    end

    it 'DBレベルのUNIQUE制約でも重複を防ぐこと(バリデーションを迂回した場合)' do
      build_customer_song_part.save!
      duplicate = build_customer_song_part

      expect {
        duplicate.save!(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'Song削除時の扱い(自己申告自体は残す)' do
    it 'Song削除後もCustomerSongPart自体は残り、song_idはnullifyされること' do
      customer_song_part = build_customer_song_part
      customer_song_part.save!
      song.destroy

      expect(customer_song_part.reload.song_id).to be_nil
      expect(CustomerSongPart.exists?(customer_song_part.id)).to eq true
    end
  end
end
