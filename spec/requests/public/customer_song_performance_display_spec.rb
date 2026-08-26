require 'rails_helper'

RSpec.describe "プロフィール画面での演奏実績・演奏可能曲の表示", type: :request do
  let(:viewer) { FactoryBot.create(:customer) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, community: community) }
  let(:song) { FactoryBot.create(:song, event: event, song_name: "テスト曲", artist_name: "テストアーティスト") }
  let(:join_part) { FactoryBot.create(:join_part, song: song, join_part_name: "Vocal") }

  before do
    CommunityCustomer.find_or_create_by!(customer: viewer, community: community)
    sign_in viewer
  end

  describe '演奏実績(イベント実績)の表示' do
    it 'プロフィールにイベント実績が表示されること' do
      FactoryBot.create(:song_performance, customer: viewer, song: song, song_master: song.song_master, event: event, join_part: join_part, part_name: "Vocal")

      get public_customer_path(viewer)

      expect(response.body).to include("演奏実績")
      expect(response.body).to include("テスト曲")
      expect(response.body).to include("Vocal")
    end

    it '同じ曲・パートを複数回演奏している場合、演奏回数が正しく表示されること' do
      other_event = FactoryBot.create(:event, :event_with_songs, community: community)
      other_song = FactoryBot.create(:song, event: other_event, song_name: "テスト曲", artist_name: "テストアーティスト")
      other_join_part = FactoryBot.create(:join_part, song: other_song, join_part_name: "Vocal")

      FactoryBot.create(:song_performance, customer: viewer, song: song, song_master: song.song_master, event: event, join_part: join_part, part_name: "Vocal")
      FactoryBot.create(:song_performance, customer: viewer, song: other_song, song_master: song.song_master, event: other_event, join_part: other_join_part, part_name: "Vocal")

      get public_customer_path(viewer)

      expect(response.body).to include("2回")
    end

    it '退会済みユーザーのプロフィールに演奏実績セクションが表示されないこと(プロフィール自体が非表示)' do
      withdrawn_customer = FactoryBot.create(:customer, is_deleted: true)
      CommunityCustomer.find_or_create_by!(customer: withdrawn_customer, community: community)
      FactoryBot.create(:song_performance, customer: withdrawn_customer, song: song, song_master: song.song_master, event: event, join_part: join_part, part_name: "Vocal")

      get public_customer_path(withdrawn_customer)

      expect(response).to redirect_to(public_communities_path)
    end

    it 'データがない場合、演奏実績セクション自体が表示されないこと' do
      get public_customer_path(viewer)

      expect(response.body).not_to include("演奏実績")
    end
  end

  describe '演奏可能曲(自己申告)の表示' do
    it '自己登録の演奏可能曲が演奏実績とは別セクションに表示されること' do
      FactoryBot.create(:customer_song_part, customer: viewer, song: song, song_master: song.song_master, part_name: "Guitar")

      get public_customer_path(viewer)

      expect(response.body).to include("演奏可能曲")
      expect(response.body).to include("Guitar")
    end

    it 'データがない場合、演奏可能曲セクション自体が表示されないこと' do
      get public_customer_path(viewer)

      expect(response.body).not_to include("演奏可能曲")
    end
  end
end
