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

  describe "パネル内の候補行" do
    before do
      sign_in owner
      show_event
    end

    let(:doc) { Nokogiri::HTML(response.body) }
    let(:panel) { doc.at_css(".entry-invitation-panel") }

    it "候補チェックボックスの name は targets[]・value は song:part:customer 形式" do
      checkbox = panel.at_css(".js-entry-invitation-checkbox")
      expect(checkbox["name"]).to eq "targets[]"
      expect(checkbox["value"]).to eq "#{current_song.id}:#{current_part.id}:#{experienced_customer.id}"
    end

    it "checkbox の id と label の for が一致する" do
      checkbox = panel.at_css(".js-entry-invitation-checkbox")
      label = panel.at_css("label.entry-invitation__label")
      expect(label["for"]).to eq checkbox["id"]
    end

    it "アバターと名前は label 内、プロフィールリンクは label の外にある" do
      label = panel.at_css("label.entry-invitation__label")
      expect(label.at_css(".avatar-with-badge")).to be_present
      expect(label.text).to include "経験太郎"
      expect(label.at_css("a")).to be_nil

      profile_link = panel.at_css("a.entry-invitation__profile")
      expect(profile_link["href"]).to eq public_customer_path(experienced_customer)
      expect(profile_link.ancestors("label")).to be_empty
    end

    it "送信ボタンはページ内に 1 つだけ" do
      expect(doc.css(".js-entry-invitation-submit").size).to eq 1
    end

    it "アクティブな候補には緑丸、非アクティブには表示されない" do
      expect(panel.at_css(".avatar-active-dot")).to be_nil

      experienced_customer.update!(last_active_at: Time.current)
      show_event
      panel = Nokogiri::HTML(response.body).at_css(".entry-invitation-panel")
      expect(panel.at_css(".avatar-active-dot")).to be_present
    end

    it "送信状態バッジ（依頼済み）を維持する" do
      FactoryBot.create(:entry_invitation,
        event: current_event, song: current_song, join_part: current_part,
        customer: experienced_customer, requested_by_customer: owner, sent_at: 1.hour.ago)
      show_event

      expect(response.body).to include "依頼済み"
    end
  end

  it "退会ユーザーは候補に表示されない" do
    withdrawn = FactoryBot.create(:customer, name: "退会花子", is_deleted: true)
    CommunityCustomer.find_or_create_by!(customer: withdrawn, community: community)
    FactoryBot.create(:join_part_customer, join_part: past_part, customer: withdrawn)

    sign_in owner
    show_event

    panel = Nokogiri::HTML(response.body).at_css(".entry-invitation-panel")
    expect(panel.text).not_to include "退会花子"
  end

  it "パネルは楽曲行の直後・イベント補足より前に表示される" do
    sign_in owner
    show_event

    songs_pos = response.body.index("event-songs-join-form")
    panel_pos = response.body.index("entry-invitation-panel")
    supplement_pos = response.body.index("イベント補足")

    expect(songs_pos).to be < panel_pos
    expect(panel_pos).to be < supplement_pos
  end

  it "パネルは 1 箇所だけに描画される（旧位置に二重表示されない）" do
    sign_in owner
    show_event

    expect(response.body.scan("entry-invitation-panel__form").size).to eq 1
  end

  it "候補のプロフィール画像取得で Active Storage の N+1 が発生しない" do
    sign_in owner

    as_query_count = lambda do
      count = 0
      counter = ->(*, payload) { count += 1 if payload[:sql] =~ /active_storage/i && payload[:name] != "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { show_event }
      count
    end

    baseline = as_query_count.call

    2.times do |i|
      s = FactoryBot.create(:song, event: current_event, song_name: "共通曲", artist_name: "共通アーティスト")
      FactoryBot.create(:join_part, song: s, join_part_name: "Vocal")
      ps = FactoryBot.create(:song, event: past_event, song_name: "共通曲", artist_name: "共通アーティスト")
      pp = FactoryBot.create(:join_part, song: ps, join_part_name: "Vocal")
      FactoryBot.create(:join_part_customer, join_part: pp, customer: FactoryBot.create(:customer, name: "追加経験者#{i}"))
    end

    expect(as_query_count.call).to eq baseline
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
