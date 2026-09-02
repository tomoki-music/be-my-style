require 'rails_helper'

RSpec.describe "プロフィール画面での演奏実績・演奏可能曲の表示", type: :request do
  let(:viewer) { FactoryBot.create(:customer) }
  let(:community) { FactoryBot.create(:community) }
  # :event factoryのデフォルト日時は固定の過去日時(2023年)のため、そのまま使えば終了済みイベントになる。
  let(:event) { FactoryBot.create(:event, :event_with_songs, community: community) }
  let(:song) { FactoryBot.create(:song, event: event, song_name: "テスト曲", artist_name: "テストアーティスト") }
  let(:join_part) { FactoryBot.create(:join_part, song: song, join_part_name: "Vocal") }

  let(:upcoming_event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community,
      event_start_time: 2.days.from_now, event_end_time: 3.days.from_now, event_entry_deadline: 1.day.from_now
    )
  end

  before do
    CommunityCustomer.find_or_create_by!(customer: viewer, community: community)
    sign_in viewer
  end

  describe '演奏実績(イベント実績)の表示' do
    it '終了済みイベントのエントリーが、確定操作なしでプロフィールに表示されること' do
      FactoryBot.create(:join_part_customer, join_part: join_part, customer: viewer)

      get public_customer_path(viewer)

      expect(response.body).to include("演奏実績")
      expect(response.body).to include("テスト曲")
      expect(response.body).to include("Vocal")
    end

    it '開催前イベントのエントリーはプロフィール実績に表示されないこと' do
      upcoming_song = FactoryBot.create(:song, event: upcoming_event, song_name: "テスト曲", artist_name: "テストアーティスト")
      upcoming_join_part = FactoryBot.create(:join_part, song: upcoming_song, join_part_name: "Vocal")
      FactoryBot.create(:join_part_customer, join_part: upcoming_join_part, customer: viewer)

      get public_customer_path(viewer)

      # ページ全体ではなく演奏実績セクション固有のDOMで判定する
      # (共通ヘッダーのナビ項目「ユーザー演奏実績ランキング」が本文に "演奏実績" を含むため)。
      expect(response.body).not_to include("performance-history-scroll")
    end

    it '同じ曲・パートを複数回演奏している場合、演奏回数が正しく表示されること' do
      other_event = FactoryBot.create(:event, :event_with_songs, community: community)
      other_song = FactoryBot.create(:song, event: other_event, song_name: "テスト曲", artist_name: "テストアーティスト")
      other_join_part = FactoryBot.create(:join_part, song: other_song, join_part_name: "Vocal")

      FactoryBot.create(:join_part_customer, join_part: join_part, customer: viewer)
      FactoryBot.create(:join_part_customer, join_part: other_join_part, customer: viewer)

      get public_customer_path(viewer)

      expect(response.body).to include("2回")
    end

    it '退会済みユーザーのプロフィールに演奏実績セクションが表示されないこと(プロフィール自体が非表示)' do
      withdrawn_customer = FactoryBot.create(:customer, is_deleted: true)
      CommunityCustomer.find_or_create_by!(customer: withdrawn_customer, community: community)
      FactoryBot.create(:join_part_customer, join_part: join_part, customer: withdrawn_customer)

      get public_customer_path(withdrawn_customer)

      expect(response).to redirect_to(public_communities_path)
    end

    it 'データがない場合、演奏実績セクション自体が表示されないこと' do
      get public_customer_path(viewer)

      # ページ全体ではなく演奏実績セクション固有のDOMで判定する
      # (共通ヘッダーのナビ項目「ユーザー演奏実績ランキング」が本文に "演奏実績" を含むため)。
      expect(response.body).not_to include("performance-history-scroll")
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
