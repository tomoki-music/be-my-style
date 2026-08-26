require 'rails_helper'

RSpec.describe "Public::CustomerSongParts", type: :request do
  let(:customer) { FactoryBot.create(:customer) }
  let(:other_customer) { FactoryBot.create(:customer) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, community: community) }
  let(:song) { FactoryBot.create(:song, event: event, song_name: "テスト曲", artist_name: "テストアーティスト") }

  before do
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
  end

  describe '未ログイン時' do
    it '曲を登録しようとするとログイン画面へリダイレクトされること' do
      post public_customer_song_parts_path, params: { customer_song_part: { song_id: song.id, part_name: "Vocal" } }
      expect(response).to redirect_to(new_customer_session_path)
    end
  end

  describe 'ログイン済み' do
    before { sign_in customer }

    describe 'create' do
      it '本人が演奏可能曲を登録できること' do
        expect {
          post public_customer_song_parts_path, params: { customer_song_part: { song_id: song.id, part_name: "Vocal" } }
        }.to change(CustomerSongPart, :count).by(1)

        expect(response).to redirect_to(edit_public_customer_path(customer))
        record = CustomerSongPart.last
        expect(record.customer_id).to eq customer.id
        expect(record.song_id).to eq song.id
        expect(record.part_name).to eq "Vocal"
      end

      it '同じ曲・パートを重複登録できないこと' do
        FactoryBot.create(:customer_song_part, customer: customer, song: song, song_master: song.song_master, part_name: "Vocal")

        expect {
          post public_customer_song_parts_path, params: { customer_song_part: { song_id: song.id, part_name: "Vocal" } }
        }.not_to change(CustomerSongPart, :count)
      end

      it '所属していないコミュニティのSongは登録できないこと' do
        other_community = FactoryBot.create(:community)
        other_event = FactoryBot.create(:event, :event_with_songs, community: other_community)
        other_song = FactoryBot.create(:song, event: other_event)

        expect {
          post public_customer_song_parts_path, params: { customer_song_part: { song_id: other_song.id, part_name: "Vocal" } }
        }.not_to change(CustomerSongPart, :count)
      end

      it '存在しないsong_idを送信しても登録されないこと' do
        expect {
          post public_customer_song_parts_path, params: { customer_song_part: { song_id: 0, part_name: "Vocal" } }
        }.not_to change(CustomerSongPart, :count)
      end

      it '候補外のpart_nameを送信しても登録されないこと' do
        expect {
          post public_customer_song_parts_path, params: { customer_song_part: { song_id: song.id, part_name: "でたらめ" } }
        }.not_to change(CustomerSongPart, :count)
      end

      it 'customer_idをパラメータで指定しても他人として登録されないこと' do
        post public_customer_song_parts_path, params: {
          customer_song_part: { song_id: song.id, part_name: "Vocal", customer_id: other_customer.id }
        }

        expect(CustomerSongPart.last.customer_id).to eq customer.id
      end
    end

    describe 'destroy' do
      it '本人が自己登録データを削除できること' do
        record = FactoryBot.create(:customer_song_part, customer: customer, song: song, song_master: song.song_master, part_name: "Vocal")

        expect {
          delete public_customer_song_part_path(record)
        }.to change(CustomerSongPart, :count).by(-1)
      end

      it '他人のデータを削除できないこと' do
        record = FactoryBot.create(:customer_song_part, customer: other_customer, song: song, song_master: song.song_master, part_name: "Vocal")

        expect {
          delete public_customer_song_part_path(record)
        }.not_to change(CustomerSongPart, :count)
      end
    end
  end

  describe '退会済みユーザーの扱い' do
    it '退会済みユーザーはログインできないため登録操作自体ができないこと' do
      customer.update!(is_deleted: true)
      post public_customer_song_parts_path, params: { customer_song_part: { song_id: song.id, part_name: "Vocal" } }

      expect(response).to redirect_to(new_customer_session_path)
    end
  end
end
