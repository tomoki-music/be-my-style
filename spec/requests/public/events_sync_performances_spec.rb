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
