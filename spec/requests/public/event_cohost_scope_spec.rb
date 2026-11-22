require "rails_helper"

# 共催先の追加で広がるのは参加条件だけで、表示範囲・編集権限・通知先は広がらないことを確認する。
RSpec.describe "共催先の追加で表示範囲・権限・通知先が広がらないこと", type: :request do
  include ActiveJob::TestHelper

  let(:organizer) { FactoryBot.create(:customer) }
  let(:site_admin) { FactoryBot.create(:customer, is_owner: :admin) }
  let(:western) { FactoryBot.create(:community, name: "洋楽セッション", owner_id: organizer.id) }
  let(:japanese) { FactoryBot.create(:community, name: "邦楽セッション", owner_id: organizer.id) }
  let(:jazz) { FactoryBot.create(:community, name: "ジャズセッション", owner_id: organizer.id) }
  let!(:event) do
    FactoryBot.create(:event, :event_with_songs,
      customer: organizer, community: western, event_name: "合同セッション",
      event_start_time: 30.days.from_now, event_end_time: 30.days.from_now + 2.hours, event_entry_deadline: 20.days.from_now)
  end
  let!(:vocal) { FactoryBot.create(:join_part, song: event.songs.first, join_part_name: "Vocal") }

  def member_of(*communities, **attributes)
    FactoryBot.create(:customer, **attributes).tap do |customer|
      communities.each { |community| CommunityCustomer.create!(customer: customer, community: community) }
    end
  end

  def add_cohost
    event.update!(selected_cohost_community_ids: [japanese.id])
  end

  def view_paths
    {
      "一覧" => public_events_path,
      "検索" => public_events_path(keyword: "邦楽"),
      "コミュニティ絞り込み" => public_events_path(community_id: japanese.id),
      "詳細" => public_event_path(event),
      "楽曲詳細" => public_event_song_path(event, event.songs.first),
      "編集" => edit_public_event_path(event)
    }
  end

  def statuses(paths)
    paths.transform_values do |path|
      get path
      [response.status, response.location]
    end
  end

  describe "表示範囲" do
    it "未ログインの人は追加の前後で同じくログイン画面へ送られる" do
      before_add = statuses(view_paths)
      add_cohost
      after_add = statuses(view_paths)

      expect(after_add).to eq before_add
      expect(after_add.values.map(&:first).uniq).to eq [302]
      expect(after_add.values.map(&:last).uniq.join).to include("sign_in")
    end

    it "音楽ドメインを使わない会員は、共催先と同じ名前の検索でも見られない" do
      outsider = FactoryBot.create(:customer, domain_name: "business")
      sign_in outsider

      before_add = statuses(view_paths)
      add_cohost
      after_add = statuses(view_paths)

      expect(after_add).to eq before_add
      expect(after_add.values.map(&:first).uniq).to eq [302]
    end

    it "どの開催コミュニティにも所属しない会員の見え方は追加の前後で変わらない" do
      sign_in member_of(jazz)
      paths = view_paths.slice("一覧", "詳細", "楽曲詳細", "編集")

      before_add = statuses(paths)
      add_cohost
      after_add = statuses(paths)

      expect(after_add).to eq before_add
      expect(after_add["一覧"]).to eq [200, nil]
      expect(after_add["詳細"]).to eq [200, nil]
      expect(after_add["編集"]).to eq [302, public_events_url]
    end

    it "別のコミュニティだけのイベントは、共催先の絞り込み・検索に混ざらない" do
      add_cohost
      FactoryBot.create(:event, :event_with_songs, community: jazz, event_name: "ジャズだけの回")
      sign_in member_of(japanese)

      get public_events_path(community_id: japanese.id)
      expect(response.body).to include("合同セッション")
      expect(response.body).not_to include("ジャズだけの回")

      get public_events_path(keyword: "邦楽")
      expect(response.body).to include("合同セッション")
      expect(response.body).not_to include("ジャズだけの回")
    end

    it "別ドメインのコミュニティは共催先にできず、そのメンバーへ表示が広がらない" do
      business = FactoryBot.create(:community, domain: Domain.find_or_create_by!(name: "business"))
      sign_in site_admin

      patch public_event_path(event), params: { event: { selected_cohost_community_ids: [business.id] } }

      expect(response.status).to eq 200
      expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id]
      expect(business.hosted_events).to be_empty
    end
  end

  describe "編集権限" do
    before { add_cohost }

    let(:added_owner) do
      FactoryBot.create(:customer, is_owner: :community_owner).tap do |owner|
        CommunityOwner.create!(customer: owner, community: japanese)
        japanese.update!(owner_id: owner.id)
      end
    end
    let(:added_editor) do
      FactoryBot.create(:customer, is_owner: :manager).tap do |editor|
        CommunityEventEditor.create!(customer: editor, community: japanese)
      end
    end

    {
      "共催先のオーナー" => :added_owner,
      "共催先のイベント編集者" => :added_editor
    }.each do |label, actor|
      it "#{label}は編集・更新・削除・コピー・エントリー依頼のどれもできない" do
        sign_in public_send(actor)

        get edit_public_event_path(event)
        expect(response).to redirect_to(public_events_path)

        patch public_event_path(event), params: { event: { event_name: "乗っ取り" } }
        expect(event.reload.event_name).to eq "合同セッション"

        expect { delete public_event_path(event) }.not_to change(Event, :count)

        get copy_public_event_path(event)
        expect(response).to redirect_to(public_events_path)

        get new_public_event_entry_invitation_path(event)
        expect(response).to redirect_to(public_event_path(event))

        get public_event_path(event)
        expect(response.body).not_to include(edit_public_event_path(event))
      end
    end

    it "共催先の一般メンバーにも編集導線を出さず、参加だけできる" do
      member = member_of(japanese)
      sign_in member

      get public_event_path(event)
      expect(response.body).not_to include(edit_public_event_path(event))

      get edit_public_event_path(event)
      expect(response).to redirect_to(public_events_path)

      expect do
        post public_event_join_path(event), params: { join_part_ids: { "0" => vocal.id.to_s } }
      end.to change { JoinPartCustomer.where(customer: member).count }.by(1)
    end
  end

  describe "通知先" do
    let!(:western_member) { member_of(western) }
    let!(:japanese_member) { member_of(japanese) }

    it "共催先を追加しても、通知・メール・チャット投稿は発生しない" do
      sign_in site_admin

      expect do
        perform_enqueued_jobs do
          patch public_event_path(event), params: { event: { selected_cohost_community_ids: [japanese.id] } }
        end
      end.to change(Notification, :count).by(0)
        .and change(ChatMessage, :count).by(0)
        .and change { ActionMailer::Base.deliveries.size }.by(0)

      expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id, japanese.id]
    end

    it "共催先のメンバーが参加しても、共催先・主催のほかのメンバーへ通知は増えない" do
      add_cohost
      sign_in japanese_member

      post public_event_join_path(event), params: { join_part_ids: { "0" => vocal.id.to_s } }

      visited = Notification.where(visitor_id: japanese_member.id).pluck(:visited_id).uniq
      expect(visited).to eq [organizer.id]
    end

    it "リクエストの ALL メンションの宛先に共催先のメンバーは入らない" do
      add_cohost
      sign_in western_member

      post public_event_requests_path(event), params: { request: { request: "[@ALL](customer:all) お願いします" } }, xhr: true

      visited = Notification.where(visitor_id: western_member.id).pluck(:visited_id)
      expect(visited).not_to include(japanese_member.id)
      expect(Requests::MentionResolver.call(request_text: "[@ALL](customer:all)", event: event, poster: organizer)).to include(western_member)
      expect(Requests::MentionResolver.call(request_text: "[@ALL](customer:all)", event: event, poster: organizer)).not_to include(japanese_member)
    end
  end

  describe "締め切りリマインド" do
    include ActiveSupport::Testing::TimeHelpers

    let(:jst) { Time.find_zone("Asia/Tokyo") }
    let(:owner) { FactoryBot.create(:customer) }
    let(:primary) { FactoryBot.create(:community, owner_id: owner.id) }
    let(:cohost) { FactoryBot.create(:community, owner_id: owner.id) }
    let(:reminded_event) do
      FactoryBot.create(:event, :event_with_songs,
        customer: owner, community: primary,
        event_start_time: jst.parse("2026-12-25 18:00"), event_end_time: jst.parse("2026-12-25 21:00"),
        event_entry_deadline: jst.parse("2026-12-17 23:59"))
    end
    let!(:primary_member) { member_of(primary) }
    let!(:cohost_member) { member_of(cohost) }

    before do
      CommunityCustomer.create!(community: primary, customer: owner)
      ActionMailer::Base.deliveries.clear
      travel_to(jst.parse("2026-12-17 08:00"))
      reminded_event.update!(selected_cohost_community_ids: [cohost.id])
    end

    after { travel_back }

    def dispatch_at_schedule(channel)
      reminded_event.update!(deadline_reminders_attributes: [{ kind: "entry", enabled: "1", channel: channel }])
      travel_to(jst.parse("2026-12-17 12:00"))
      EventDeadlineReminders::Dispatcher.call(now: Time.current)
    end

    it "メールは主催のメンバーだけに届き、共催先のメンバーには届かない" do
      dispatch_at_schedule("mail")

      recipients = ActionMailer::Base.deliveries.flat_map(&:to)
      expect(recipients).to include(primary_member.email)
      expect(recipients).not_to include(cohost_member.email)
    end

    it "チャットは主催のチャットだけに投稿し、共催先のメンバーへの通知は作らない" do
      chat_room = ChatRoom.create!
      ChatRoomCustomer.create!(chat_room: chat_room, customer: owner, community: primary)

      dispatch_at_schedule("chat")

      expect(ChatMessage.last.community).to eq primary
      expect(Notification.where(visited_id: primary_member.id)).to exist
      expect(Notification.where(visited_id: cohost_member.id)).not_to exist
    end
  end
end
