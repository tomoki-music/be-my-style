require 'rails_helper'

RSpec.describe "Admin::Events", type: :request do
  let(:admin) { FactoryBot.create(:admin) }
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { FactoryBot.create(:song, event: event) }

  describe 'ログイン済み' do
    before do
      sign_in admin
    end
    context "event一覧ページ(index)が正しく表示される" do
      before do
        get admin_events_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "event詳細ページ(show)が正しく表示される" do
      before do
        get admin_event_path(event)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "eventページを正しく削除(destroy)できる" do
      it '正しく削除できる' do
        event
        expect do
          delete admin_event_path(event)
        end.to change(Event, :count).by(-1)
      end
    end
    context "event参加メンバーを正しく削除(delete)できる" do
      it '正しくメンバー削除できる' do
        event
        join_part = JoinPart.create(song_id: song.id, join_part_name: "vocal")
        JoinPartCustomer.create(customer_id: customer.id, join_part_id: join_part.id)
        expect do
          delete admin_event_delete_path(event, customer_id: customer, join_part_id: join_part.id)
        end.to change(JoinPartCustomer, :count).by(-1)
      end
    end
    context "event新規作成(create)が正しく処理され登録される" do
      it "曲のコード譜情報(URL・Key・Capo・メモ)を登録できること" do
        params = admin_event_create_params(community, customer)
        params[:event][:songs_attributes]["0"][:chord_sheet_url] = "https://example.com/chord-sheet"
        params[:event][:songs_attributes]["0"][:musical_key] = "G"
        params[:event][:songs_attributes]["0"][:capo] = 2
        params[:event][:songs_attributes]["0"][:chord_sheet_note] = "初心者向けの簡単コード版です"

        post admin_events_path, params: params

        created_song = Song.last
        expect(created_song.chord_sheet_url).to eq "https://example.com/chord-sheet"
        expect(created_song.musical_key).to eq "G"
        expect(created_song.capo).to eq 2
        expect(created_song.chord_sheet_note).to eq "初心者向けの簡単コード版です"
      end

      it "曲のアーティスト名を登録できること(既存不整合の修正確認)" do
        params = admin_event_create_params(community, customer)
        params[:event][:songs_attributes]["0"][:artist_name] = "テストアーティスト"

        post admin_events_path, params: params

        expect(Song.last.artist_name).to eq "テストアーティスト"
      end

      it "コード譜情報を入力しなくても曲を作成できること" do
        expect do
          post admin_events_path, params: admin_event_create_params(community, customer)
        end.to change(Song, :count).by(1)

        created_song = Song.last
        expect(created_song.chord_sheet_url).to be_nil
        expect(created_song.musical_key).to be_nil
        expect(created_song.capo).to be_nil
        expect(created_song.chord_sheet_note).to be_nil
      end

      it "曲のTAB譜URLを登録できること" do
        params = admin_event_create_params(community, customer)
        params[:event][:songs_attributes]["0"][:tab_sheet_url] = "https://example.com/tab-sheet"

        post admin_events_path, params: params

        expect(Song.last.tab_sheet_url).to eq "https://example.com/tab-sheet"
      end

      it "TAB譜URLを入力しなくても曲を作成できること" do
        expect do
          post admin_events_path, params: admin_event_create_params(community, customer)
        end.to change(Song, :count).by(1)

        expect(Song.last.tab_sheet_url).to be_nil
      end
    end
    context "event編集(update)が正しく処理され登録される" do
      it "既存の曲のコード譜情報(URL・Key・Capo・メモ)を編集できること" do
        target_song = event.songs.first

        put admin_event_path(event), params: {
          event: {
            songs_attributes: {
              "0" => {
                id: target_song.id,
                chord_sheet_url: "https://example.com/chord-sheet",
                musical_key: "Am",
                capo: 3,
                chord_sheet_note: "原曲より半音下げ"
              }
            }
          }
        }

        target_song.reload
        expect(target_song.chord_sheet_url).to eq "https://example.com/chord-sheet"
        expect(target_song.musical_key).to eq "Am"
        expect(target_song.capo).to eq 3
        expect(target_song.chord_sheet_note).to eq "原曲より半音下げ"
      end

      it "既存の曲のアーティスト名を編集できること(既存不整合の修正確認)" do
        target_song = event.songs.first

        put admin_event_path(event), params: {
          event: {
            songs_attributes: {
              "0" => { id: target_song.id, artist_name: "編集後アーティスト" }
            }
          }
        }

        expect(target_song.reload.artist_name).to eq "編集後アーティスト"
      end

      it "既存の曲のTAB譜URLを編集できること" do
        target_song = event.songs.first

        put admin_event_path(event), params: {
          event: {
            songs_attributes: {
              "0" => {
                id: target_song.id,
                tab_sheet_url: "https://example.com/tab-sheet"
              }
            }
          }
        }

        expect(target_song.reload.tab_sheet_url).to eq "https://example.com/tab-sheet"
      end
    end
  end

  describe '非ログイン' do
    context "events一覧ページ(index)へ遷移されない" do
      before do
        get admin_events_path
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "event詳細ページ(show)へ遷移されない" do
      before do
        get admin_event_path(event)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "eventページを正しく削除(destroy)できない" do
      it 'リクエストは302 Foundとなること' do
        delete admin_event_path(event)
        expect(response.status).to eq 302
      end
    end
  end

  def admin_event_create_params(community, customer)
    {
      event: {
        customer_id: customer.id,
        community_id: community.id,
        event_name: "管理者作成イベント",
        event_start_time: 7.days.from_now,
        event_end_time: 7.days.from_now + 2.hours,
        event_entry_deadline: 6.days.from_now,
        entrance_fee: 1500,
        place: "MMMstudio",
        address: "埼玉県さいたま市",
        introduction: "管理者が作成したイベントです",
        songs_attributes: {
          "0" => {
            song_name: "Session Song",
            performance_time: "5:00",
            join_parts_attributes: {
              "0" => { join_part_name: "Vocal" }
            }
          }
        }
      }
    }
  end
end
