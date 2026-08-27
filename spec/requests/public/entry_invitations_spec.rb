require 'rails_helper'

RSpec.describe "Public::EntryInvitations", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:community) { FactoryBot.create(:community) }
  let(:owner) { FactoryBot.create(:customer, :customer_with_parts, name: "オーナー") }
  let(:admin) { FactoryBot.create(:customer, is_owner: :admin) }
  let(:general_member) { FactoryBot.create(:customer, name: "一般ユーザー") }
  let(:experienced_customer) { FactoryBot.create(:customer, name: "経験太郎") }

  let(:past_event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community, customer: owner,
      event_start_time: 3.days.ago, event_end_time: 2.days.ago, event_entry_deadline: 4.days.ago
    )
  end
  let(:current_event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community, customer: owner,
      event_start_time: 2.days.from_now, event_end_time: 3.days.from_now, event_entry_deadline: 1.day.from_now
    )
  end
  let(:past_song) { FactoryBot.create(:song, event: past_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:current_song) { FactoryBot.create(:song, event: current_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:past_part) { FactoryBot.create(:join_part, song: past_song, join_part_name: "Vocal") }
  let(:current_part) { FactoryBot.create(:join_part, song: current_song, join_part_name: "Vocal") }

  before do
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    [owner, general_member, experienced_customer].each do |c|
      CommunityCustomer.find_or_create_by!(customer: c, community: community)
    end
    current_part
    FactoryBot.create(:join_part_customer, join_part: past_part, customer: experienced_customer)
  end

  def create_path
    public_event_entry_invitations_path(current_event)
  end

  def valid_params(customer_ids: [experienced_customer.id])
    { entry_invitation: { song_id: current_song.id, join_part_id: current_part.id, customer_ids: customer_ids } }
  end

  describe "POST /create 認可" do
    it "一般ユーザーのPOSTを拒否し、何も送信しない" do
      sign_in general_member

      expect {
        post create_path, params: valid_params
      }.not_to change(EntryInvitation, :count)

      expect(response).to redirect_to(public_event_path(current_event))
    end

    it "未ログインユーザーのPOSTを拒否する" do
      expect {
        post create_path, params: valid_params
      }.not_to change(EntryInvitation, :count)

      expect(response).to have_http_status(:found)
    end

    it "管理者はPOSTできる" do
      sign_in admin

      perform_enqueued_jobs do
        expect {
          post create_path, params: valid_params
        }.to change(EntryInvitation, :count).by(1)
      end

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq [[experienced_customer.email]]
    end

    it "イベントオーナーはPOSTできる" do
      sign_in owner

      expect {
        post create_path, params: valid_params
      }.to change(EntryInvitation, :count).by(1)
    end
  end

  describe "POST /create 送信対象" do
    before { sign_in owner }

    it "選択した経験者だけに個別メールが届く" do
      other = FactoryBot.create(:customer, name: "別経験者")
      CommunityCustomer.find_or_create_by!(customer: other, community: community)
      FactoryBot.create(:join_part_customer, join_part: past_part, customer: other)

      perform_enqueued_jobs do
        post create_path, params: valid_params(customer_ids: [experienced_customer.id])
      end

      expect(ActionMailer::Base.deliveries.size).to eq 1
      expect(ActionMailer::Base.deliveries.last.to).to eq [experienced_customer.email]
    end

    it "customer_id改ざんで無関係な人へは送信できない" do
      stranger = FactoryBot.create(:customer, name: "無関係")

      expect {
        perform_enqueued_jobs do
          post create_path, params: valid_params(customer_ids: [stranger.id])
        end
      }.not_to change(EntryInvitation, :count)

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "二重クリック（同一POSTを2回）でも配信は1通のみ" do
      perform_enqueued_jobs do
        post create_path, params: valid_params
        post create_path, params: valid_params
      end

      expect(EntryInvitation.where(customer_id: experienced_customer.id).count).to eq 1
      expect(ActionMailer::Base.deliveries.size).to eq 1
    end

    it "開催終了後は送信できない" do
      travel_to(5.days.from_now) do
        expect {
          post create_path, params: valid_params
        }.not_to change(EntryInvitation, :count)
      end
    end

    it "送信履歴（status/sent_at/各id/送信者）が保存される" do
      post create_path, params: valid_params

      invitation = EntryInvitation.last
      expect(invitation).to have_attributes(
        event_id: current_event.id, song_id: current_song.id, join_part_id: current_part.id,
        customer_id: experienced_customer.id, requested_by_customer_id: owner.id, status: "pending"
      )
      expect(invitation.sent_at).to be_present
    end
  end

  describe "GET /new 確認画面" do
    before { sign_in owner }

    it "イベント・曲・パート・送信対象者・人数を表示する" do
      get new_public_event_entry_invitation_path(current_event, song_id: current_song.id, join_part_id: current_part.id, customer_ids: [experienced_customer.id])

      expect(response).to have_http_status(:ok)
      expect(response.body).to include current_event.event_name
      expect(response.body).to include "共通曲"
      expect(response.body).to include "共通アーティスト"
      expect(response.body).to include "Vocal"
      expect(response.body).to include "経験太郎"
      expect(response.body).to include "1人"
    end

    it "対象者未選択なら送信できずイベントへ戻す" do
      get new_public_event_entry_invitation_path(current_event, song_id: current_song.id, join_part_id: current_part.id)

      expect(response).to redirect_to(public_event_path(current_event))
    end
  end
end
