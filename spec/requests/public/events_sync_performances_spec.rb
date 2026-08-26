require 'rails_helper'

RSpec.describe "Public::Events#sync_performances", type: :request do
  let(:organizer) { FactoryBot.create(:customer) }
  let(:member) { FactoryBot.create(:customer) }
  let(:other_customer) { FactoryBot.create(:customer) }
  let(:community) { FactoryBot.create(:community) }
  let(:ended_event) do
    FactoryBot.create(
      :event,
      :event_with_songs,
      customer: organizer,
      community: community,
      event_start_time: 3.days.ago,
      event_end_time: 2.days.ago,
      event_entry_deadline: 4.days.ago
    )
  end
  let(:upcoming_event) do
    FactoryBot.create(
      :event,
      :event_with_songs,
      customer: organizer,
      community: community,
      event_start_time: 3.days.from_now,
      event_end_time: 4.days.from_now,
      event_entry_deadline: 2.days.from_now
    )
  end

  before do
    CommunityCustomer.find_or_create_by!(customer: organizer, community: community)
    CommunityCustomer.find_or_create_by!(customer: member, community: community)
    CommunityOwner.find_or_create_by!(customer: organizer, community: community)
  end

  def entry_for(event, customer, part_name: "Vocal")
    song = FactoryBot.create(:song, event: event)
    join_part = FactoryBot.create(:join_part, song: song, join_part_name: part_name)
    FactoryBot.create(:join_part_customer, join_part: join_part, customer: customer)
  end

  describe '主催者/管理者による確定' do
    before { sign_in organizer }

    it '終了済みイベントで演奏実績を確定できること' do
      entry_for(ended_event, member)

      expect {
        post sync_performances_public_event_path(ended_event)
      }.to change(SongPerformance, :count).by(1)

      expect(response).to redirect_to(public_event_path(ended_event))
    end

    it '開催前イベントでは確定できない(演奏実績が作成されない)こと' do
      entry_for(upcoming_event, member)

      expect {
        post sync_performances_public_event_path(upcoming_event)
      }.not_to change(SongPerformance, :count)
    end

    it '何度実行しても重複登録されないこと' do
      entry_for(ended_event, member)
      post sync_performances_public_event_path(ended_event)

      expect {
        post sync_performances_public_event_path(ended_event)
      }.not_to change(SongPerformance, :count)
    end

    it 'JoinPart::NAME_OPTIONSに含まれないレガシーpart_nameは、"登録済み"と偽らずフラッシュに表示されること' do
      entry_for(ended_event, member, part_name: "ボーカル")

      expect {
        post sync_performances_public_event_path(ended_event)
      }.not_to change(SongPerformance, :count)

      expect(flash[:notice]).not_to include("登録済み1件")
      expect(flash[:notice]).to include("登録できなかった")
    end
  end

  describe '確定操作から表示までの一連の流れ(実際にsync_performancesを経由する)' do
    before { sign_in organizer }

    it '確定後、対象メンバーのプロフィールに演奏実績として表示されること' do
      song = FactoryBot.create(:song, event: ended_event, song_name: "統合テスト曲", artist_name: "統合テストアーティスト")
      join_part = FactoryBot.create(:join_part, song: song, join_part_name: "Vocal")
      FactoryBot.create(:join_part_customer, join_part: join_part, customer: member)

      post sync_performances_public_event_path(ended_event)

      sign_out organizer
      sign_in member
      get public_customer_path(member)

      expect(response.body).to include("演奏実績")
      expect(response.body).to include("統合テスト曲")
      expect(response.body).to include("Vocal")
    end

    it '確定後、別の(現在開催中の)イベントの楽曲パート募集欄で経験者として表示されること' do
      song = FactoryBot.create(:song, event: ended_event, song_name: "統合テスト曲2", artist_name: "統合テストアーティスト2")
      join_part = FactoryBot.create(:join_part, song: song, join_part_name: "Guitar")
      FactoryBot.create(:join_part_customer, join_part: join_part, customer: member)

      post sync_performances_public_event_path(ended_event)

      current_event = FactoryBot.create(
        :event, :event_with_songs, community: community,
        event_start_time: 2.days.from_now, event_end_time: 3.days.from_now, event_entry_deadline: 1.day.from_now
      )
      current_song = FactoryBot.create(:song, event: current_event, song_name: "統合テスト曲2", artist_name: "統合テストアーティスト2")
      FactoryBot.create(:join_part, song: current_song, join_part_name: "Guitar")

      get public_event_path(current_event)

      expect(response.body).to include("演奏経験のある人")
    end

    it '既存Song(song_master_id未設定)を含むイベントで確定しても、以降その曲の経験者検索が機能すること' do
      song = FactoryBot.create(:song, event: ended_event, song_name: "移行前データ曲", artist_name: "移行前アーティスト")
      song.update_column(:song_master_id, nil) # 移行前(callback未導入時)のレガシーSongを模擬
      join_part = FactoryBot.create(:join_part, song: song, join_part_name: "Bass")
      FactoryBot.create(:join_part_customer, join_part: join_part, customer: member)

      post sync_performances_public_event_path(ended_event)
      expect(SongPerformance.count).to eq 1

      current_event = FactoryBot.create(
        :event, :event_with_songs, community: community,
        event_start_time: 2.days.from_now, event_end_time: 3.days.from_now, event_entry_deadline: 1.day.from_now
      )
      current_song = FactoryBot.create(:song, event: current_event, song_name: "移行前データ曲", artist_name: "移行前アーティスト")
      FactoryBot.create(:join_part, song: current_song, join_part_name: "Bass")

      get public_event_path(current_event)

      expect(response.body).to include("演奏経験のある人")
    end
  end

  describe '一般ユーザーは確定できないこと' do
    before { sign_in other_customer }

    it '演奏実績が作成されないこと' do
      entry_for(ended_event, member)

      expect {
        post sync_performances_public_event_path(ended_event)
      }.not_to change(SongPerformance, :count)
    end
  end

  describe '未ログイン時' do
    it 'ログイン画面へリダイレクトされること' do
      post sync_performances_public_event_path(ended_event)
      expect(response).to redirect_to(new_customer_session_path)
    end
  end
end
