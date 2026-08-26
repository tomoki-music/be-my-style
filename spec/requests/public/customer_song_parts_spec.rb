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

    describe '自由入力(イベントに存在しない曲)での登録' do
      it '曲名・アーティスト名・パートの自由入力で新しいSongMasterとCustomerSongPartを登録できること' do
        expect {
          post public_customer_song_parts_path, params: {
            customer_song_part: { song_name: "自由入力の曲", artist_name: "自由入力アーティスト", part_name: "Guitar" }
          }
        }.to change(SongMaster, :count).by(1).and change(CustomerSongPart, :count).by(1)

        record = CustomerSongPart.last
        expect(record.customer_id).to eq customer.id
        expect(record.song_id).to be_nil
        expect(record.song_master.song_name).to eq "自由入力の曲"
        expect(record.song_master.artist_name).to eq "自由入力アーティスト"
        expect(response).to redirect_to(edit_public_customer_path(customer))
      end

      it 'アーティスト名は未入力でも登録できること(既存Songの仕様に合わせる)' do
        expect {
          post public_customer_song_parts_path, params: {
            customer_song_part: { song_name: "アーティスト未設定の曲", artist_name: "", part_name: "Vocal" }
          }
        }.to change(CustomerSongPart, :count).by(1)
      end

      it '曲名が未入力なら登録されないこと' do
        expect {
          post public_customer_song_parts_path, params: {
            customer_song_part: { song_name: "", artist_name: "アーティスト", part_name: "Vocal" }
          }
        }.not_to change(CustomerSongPart, :count)
      end

      it '正規化キーが完全一致する既存SongMasterがあれば再利用すること(新規作成しない)' do
        existing_master = SongMasters::Resolver.call(song_name: "Amazing Grace", artist_name: "Artist X")

        expect {
          post public_customer_song_parts_path, params: {
            customer_song_part: { song_name: "ａｍａｚｉｎｇ ｇｒａｃｅ", artist_name: "ARTIST X", part_name: "Vocal" }
          }
        }.not_to change(SongMaster, :count)

        expect(CustomerSongPart.last.song_master_id).to eq existing_master.id
      end

      it '曲名が同じでもアーティスト名が異なれば別のSongMasterとして登録されること' do
        post public_customer_song_parts_path, params: {
          customer_song_part: { song_name: "同名の曲", artist_name: "アーティストA", part_name: "Vocal" }
        }
        first_master_id = CustomerSongPart.last.song_master_id

        post public_customer_song_parts_path, params: {
          customer_song_part: { song_name: "同名の曲", artist_name: "アーティストB", part_name: "Vocal" }
        }

        expect(CustomerSongPart.last.song_master_id).not_to eq first_master_id
      end

      it '自由入力でも同じ曲(song_master)・パートの重複登録はできないこと' do
        post public_customer_song_parts_path, params: {
          customer_song_part: { song_name: "重複テスト曲", artist_name: "アーティスト", part_name: "Vocal" }
        }

        expect {
          post public_customer_song_parts_path, params: {
            customer_song_part: { song_name: "重複テスト曲", artist_name: "アーティスト", part_name: "Vocal" }
          }
        }.not_to change(CustomerSongPart, :count)
      end

      it '候補外のpart_nameを送信した場合、中途半端なSongMasterを残さないこと' do
        expect {
          post public_customer_song_parts_path, params: {
            customer_song_part: { song_name: "登録されないはずの曲", artist_name: "アーティスト", part_name: "でたらめ" }
          }
        }.not_to change(SongMaster, :count)

        expect(SongMaster.exists?(song_name: "登録されないはずの曲")).to eq false
      end

      it '曲名・アーティスト名の前後の空白を除去して登録すること' do
        post public_customer_song_parts_path, params: {
          customer_song_part: { song_name: "  空白テスト曲  ", artist_name: "  空白アーティスト  ", part_name: "Vocal" }
        }

        record = CustomerSongPart.last
        expect(record.song_master.song_name).to eq "空白テスト曲"
        expect(record.song_master.artist_name).to eq "空白アーティスト"
      end

      it '曲名・アーティスト名が上限文字数を超える場合は切り詰めて登録すること' do
        long_name = "あ" * 300

        post public_customer_song_parts_path, params: {
          customer_song_part: { song_name: long_name, artist_name: "", part_name: "Vocal" }
        }

        expect(CustomerSongPart.last.song_master.song_name.length).to eq Public::CustomerSongPartsController::MAX_TEXT_LENGTH
      end

      it '他人のcustomer_idを指定しても、自由入力登録が本人名義になること' do
        post public_customer_song_parts_path, params: {
          customer_song_part: {
            song_name: "なりすまし防止テスト曲", artist_name: "", part_name: "Vocal", customer_id: other_customer.id
          }
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
