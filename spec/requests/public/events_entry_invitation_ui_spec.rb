require 'rails_helper'

RSpec.describe "Public::Events#show エントリー依頼パネルの表示", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:community) { FactoryBot.create(:community) }
  let(:owner) { FactoryBot.create(:customer, :customer_with_parts, name: "オーナー") }
  let(:admin) { FactoryBot.create(:customer, is_owner: :admin) }
  let(:manager) { FactoryBot.create(:customer, :customer_with_parts, name: "共同オーナー") }
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
    CommunityOwner.find_or_create_by!(customer: manager, community: community)
    [owner, manager, general_member, experienced_customer].each do |c|
      CommunityCustomer.find_or_create_by!(customer: c, community: community)
    end
    current_part
    FactoryBot.create(:join_part_customer, join_part: past_part, customer: experienced_customer)
  end

  def show_event
    get public_event_path(current_event)
  end

  it "イベントオーナーには送信パネル（チェックボックス・送信ボタン）が表示される" do
    sign_in owner
    show_event

    expect(response.body).to include "entry-invitation-panel"
    expect(response.body).to include "js-entry-invitation-checkbox"
    expect(response.body).to include "js-entry-invitation-submit"
    expect(response.body).to include "経験太郎"
  end

  it "管理者にも表示される" do
    sign_in admin
    show_event
    expect(response.body).to include "js-entry-invitation-submit"
  end

  it "コミュニティ管理権限者にも表示される" do
    sign_in manager
    show_event
    expect(response.body).to include "js-entry-invitation-submit"
  end

  it "一般ユーザーには表示されない（経験者名とプロフィールリンクのみ）" do
    sign_in general_member
    show_event

    expect(response.body).not_to include "js-entry-invitation-checkbox"
    expect(response.body).not_to include "js-entry-invitation-submit"
    expect(response.body).to include "経験太郎"
  end

  it "未ログインユーザーにはイベント詳細自体が表示されない（リダイレクト）" do
    show_event
    expect(response).to have_http_status(:found)
  end

  it "演奏経験者がいない場合は送信パネルを表示しない" do
    JoinPartCustomer.delete_all
    sign_in owner
    show_event

    expect(response.body).not_to include "entry-invitation-panel"
  end

  it "開催終了後は送信パネルを表示しない" do
    sign_in owner
    travel_to(5.days.from_now) { show_event }

    expect(response.body).not_to include "entry-invitation-panel"
  end

  it "曲・パートが増えてもエントリー依頼取得のクエリ数が一定（N+1しない）" do
    sign_in owner

    query_count = lambda do
      count = 0
      counter = ->(*, payload) { count += 1 if payload[:sql] =~ /\bentry_invitations\b/i && payload[:name] != "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { show_event }
      count
    end

    baseline = query_count.call

    # current_event にもう2曲（同じ経験者が経験済み）を足す
    2.times do |i|
      s = FactoryBot.create(:song, event: current_event, song_name: "共通曲", artist_name: "共通アーティスト")
      p = FactoryBot.create(:join_part, song: s, join_part_name: "Vocal")
      ps = FactoryBot.create(:song, event: past_event, song_name: "共通曲", artist_name: "共通アーティスト")
      pp = FactoryBot.create(:join_part, song: ps, join_part_name: "Vocal")
      FactoryBot.create(:join_part_customer, join_part: pp, customer: FactoryBot.create(:customer, name: "経験者#{i}"))
    end

    expect(query_count.call).to eq baseline
  end
end
