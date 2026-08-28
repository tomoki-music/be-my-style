require 'rails_helper'

RSpec.describe "Public::EntryInvitations", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:community) { FactoryBot.create(:community) }
  let(:owner) { FactoryBot.create(:customer, :customer_with_parts, name: "オーナー") }
  let(:admin) { FactoryBot.create(:customer, is_owner: :admin) }
  let(:general_member) { FactoryBot.create(:customer, name: "一般ユーザー") }
  let(:experienced_customer) { FactoryBot.create(:customer, name: "経験太郎") }
  let(:experienced_guitarist) { FactoryBot.create(:customer, name: "ギター花子") }

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
  # 曲A: Vocal / Guitar
  let(:past_song_a) { FactoryBot.create(:song, event: past_event, song_name: "曲A", artist_name: "アーティストA") }
  let(:current_song_a) { FactoryBot.create(:song, event: current_event, song_name: "曲A", artist_name: "アーティストA") }
  let(:past_vocal) { FactoryBot.create(:join_part, song: past_song_a, join_part_name: "Vocal") }
  let(:current_vocal) { FactoryBot.create(:join_part, song: current_song_a, join_part_name: "Vocal") }
  let(:past_guitar) { FactoryBot.create(:join_part, song: past_song_a, join_part_name: "Guitar") }
  let(:current_guitar) { FactoryBot.create(:join_part, song: current_song_a, join_part_name: "Guitar") }
  # 曲B: Vocal
  let(:past_song_b) { FactoryBot.create(:song, event: past_event, song_name: "曲B", artist_name: "アーティストB") }
  let(:current_song_b) { FactoryBot.create(:song, event: current_event, song_name: "曲B", artist_name: "アーティストB") }
  let(:past_vocal_b) { FactoryBot.create(:join_part, song: past_song_b, join_part_name: "Vocal") }
  let(:current_vocal_b) { FactoryBot.create(:join_part, song: current_song_b, join_part_name: "Vocal") }

  before do
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    [owner, general_member, experienced_customer, experienced_guitarist].each do |c|
      CommunityCustomer.find_or_create_by!(customer: c, community: community)
    end
    # 現在イベント側の募集中スロット
    current_vocal
    current_guitar
    current_vocal_b
    # 演奏実績(終了済みイベント)
    FactoryBot.create(:join_part_customer, join_part: past_vocal, customer: experienced_customer)
    FactoryBot.create(:join_part_customer, join_part: past_guitar, customer: experienced_guitarist)
    FactoryBot.create(:join_part_customer, join_part: past_vocal_b, customer: experienced_customer)
  end

  def target(song, part, customer)
    "#{song.id}:#{part.id}:#{customer.id}"
  end

  def new_path(targets)
    new_public_event_entry_invitation_path(current_event, targets: targets)
  end

  def create_path
    public_event_entry_invitations_path(current_event)
  end

  describe "GET /new 確認画面" do
    before { sign_in owner }

    it "有効な targets で確認画面を表示し、曲・パート単位でグループ表示する" do
      get new_path([
        target(current_song_a, current_vocal, experienced_customer),
        target(current_song_a, current_guitar, experienced_guitarist),
        target(current_song_b, current_vocal_b, experienced_customer)
      ])

      expect(response).to have_http_status(:ok)
      expect(response.body).to include "曲A"
      expect(response.body).to include "曲B"
      expect(response.body).to include "Vocal"
      expect(response.body).to include "Guitar"
      expect(response.body).to include "経験太郎"
      expect(response.body).to include "ギター花子"
      expect(response.body).to include "3人"
    end

    it "hidden field には検証済み targets だけが入る（不正・対象外は戻さない）" do
      stranger = FactoryBot.create(:customer, name: "無関係")

      get new_path([
        target(current_song_a, current_vocal, experienced_customer),
        target(current_song_a, current_vocal, stranger),
        "not-a-target",
        "#{current_song_a.id}:#{current_vocal.id}:99999999"
      ])

      doc = Nokogiri::HTML(response.body)
      hidden_values = doc.css('input[type=hidden][name="targets[]"]').map { |n| n["value"] }
      expect(hidden_values).to contain_exactly(target(current_song_a, current_vocal, experienced_customer))
    end

    it "不正な形式の targets は無視する" do
      get new_path(["abc", "1:2", "1:2:3:4", "", "-1:2:3", target(current_song_a, current_vocal, experienced_customer)])

      expect(response).to have_http_status(:ok)
      expect(response.body).to include "経験太郎"
    end

    it "Event 外の Song を指定した target は拒否する" do
      other_event = FactoryBot.create(:event, :event_with_songs, community: community, customer: owner,
        event_start_time: 5.days.from_now, event_end_time: 6.days.from_now, event_entry_deadline: 4.days.from_now)
      other_song = FactoryBot.create(:song, event: other_event, song_name: "曲A", artist_name: "アーティストA")
      other_part = FactoryBot.create(:join_part, song: other_song, join_part_name: "Vocal")

      get new_path([target(other_song, other_part, experienced_customer)])

      expect(response).to redirect_to(public_event_path(current_event))
    end

    it "Song 外の JoinPart を指定した target は拒否する" do
      get new_path([target(current_song_a, current_vocal_b, experienced_customer)])

      expect(response).to redirect_to(public_event_path(current_event))
    end

    it "演奏経験のない Customer は拒否する" do
      get new_path([target(current_song_a, current_vocal, experienced_guitarist)])

      expect(response).to redirect_to(public_event_path(current_event))
    end

    it "退会 Customer は拒否する" do
      withdrawn = FactoryBot.create(:customer, name: "退会者", is_deleted: true)
      FactoryBot.create(:join_part_customer, join_part: past_vocal, customer: withdrawn)

      get new_path([target(current_song_a, current_vocal, withdrawn)])

      expect(response).to redirect_to(public_event_path(current_event))
    end

    it "募集が終了したパートは拒否する" do
      FactoryBot.create(:join_part_customer, join_part: current_vocal, customer: FactoryBot.create(:customer))

      get new_path([target(current_song_a, current_vocal, experienced_customer)])

      expect(response).to redirect_to(public_event_path(current_event))
    end

    it "対象者未選択ならイベント詳細へ戻す" do
      get new_path([])

      expect(response).to redirect_to(public_event_path(current_event))
    end

    it "上限を超える件数は案内してイベント詳細へ戻す" do
      targets = Array.new(EntryInvitations::TargetParser::MAX_TARGETS + 1) { |i| "#{current_song_a.id}:#{current_vocal.id}:#{i + 1}" }

      get new_path(targets)

      expect(response).to redirect_to(public_event_path(current_event))
      expect(flash[:alert]).to include EntryInvitations::TargetParser::MAX_TARGETS.to_s
    end

    it "権限のないユーザーはイベント詳細へ戻す" do
      sign_in general_member
      get new_path([target(current_song_a, current_vocal, experienced_customer)])

      expect(response).to redirect_to(public_event_path(current_event))
    end

    it "Active Storage の N+1 が発生しない（候補が増えてもクエリ数一定）" do
      def as_query_count
        count = 0
        counter = ->(*, payload) { count += 1 if payload[:sql] =~ /active_storage/i && payload[:name] != "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
        count
      end

      baseline = as_query_count do
        get new_path([target(current_song_a, current_vocal, experienced_customer)])
      end

      3.times do |i|
        c = FactoryBot.create(:customer, name: "追加経験者#{i}")
        FactoryBot.create(:join_part_customer, join_part: past_vocal, customer: c)
      end
      more = Customer.where("name LIKE '追加経験者%'").map { |c| target(current_song_a, current_vocal, c) }

      expect(as_query_count { get new_path([target(current_song_a, current_vocal, experienced_customer), *more]) }).to eq baseline
    end
  end

  describe "POST /create" do
    before { sign_in owner }

    def create_params(targets)
      { targets: targets }
    end

    it "複数の曲・パートを 1 回のリクエストでまとめて送信する" do
      perform_enqueued_jobs do
        post create_path, params: create_params([
          target(current_song_a, current_vocal, experienced_customer),
          target(current_song_a, current_guitar, experienced_guitarist),
          target(current_song_b, current_vocal_b, experienced_customer)
        ])
      end

      expect(EntryInvitation.count).to eq 3
      # メール・通知は曲・パート単位（経験太郎には曲A・曲Bで2通）
      expect(ActionMailer::Base.deliveries.map { |m| m.to.first }.tally).to eq(
        experienced_customer.email => 2,
        experienced_guitarist.email => 1
      )
      expect(flash[:notice]).to include "3件"
    end

    it "同じ target を複数回送っても 1 回だけ処理する" do
      t = target(current_song_a, current_vocal, experienced_customer)

      expect {
        post create_path, params: create_params([t, t, t])
      }.to change(EntryInvitation, :count).by(1)
    end

    it "同じユーザーへ別の曲を選んだ場合は曲ごとに依頼レコードが作られる" do
      post create_path, params: create_params([
        target(current_song_a, current_vocal, experienced_customer),
        target(current_song_b, current_vocal_b, experienced_customer)
      ])

      expect(EntryInvitation.where(customer_id: experienced_customer.id).pluck(:song_id))
        .to contain_exactly(current_song_a.id, current_song_b.id)
    end

    it "create でも改ざん target を再検証して無関係な人へは送信しない" do
      stranger = FactoryBot.create(:customer, name: "無関係")

      expect {
        perform_enqueued_jobs do
          post create_path, params: create_params([target(current_song_a, current_vocal, stranger)])
        end
      }.not_to change(EntryInvitation, :count)

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(response).to redirect_to(public_event_path(current_event))
    end

    # UI では disabled チェックボックスとして描画され targets[] を持たない候補。
    # devtools 等で token を手組みして POST しても、サーバー側(TargetResolver / Sender)が
    # 再検証して送信しないことを保証する。
    it "改ざん: 募集終了パート(UI では disabled)の token を手動 POST しても送信しない" do
      FactoryBot.create(:join_part_customer, join_part: current_vocal, customer: FactoryBot.create(:customer))

      expect {
        perform_enqueued_jobs do
          post create_path, params: create_params([target(current_song_a, current_vocal, experienced_customer)])
        end
      }.not_to change(EntryInvitation, :count)

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(response).to redirect_to(public_event_path(current_event))
    end

    it "改ざん: 24時間以内に依頼済み(UI では disabled)の token を単独で手動 POST してもメールは飛ばない" do
      FactoryBot.create(:entry_invitation,
        event: current_event, song: current_song_a, join_part: current_vocal,
        customer: experienced_customer, requested_by_customer: owner, sent_at: 1.hour.ago)

      perform_enqueued_jobs do
        post create_path, params: create_params([target(current_song_a, current_vocal, experienced_customer)])
      end

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(EntryInvitation.where(song: current_song_a, join_part: current_vocal, customer: experienced_customer).count).to eq 1
    end

    it "24時間以内に送信済みの対象はスキップし、部分成功の flash を出す" do
      FactoryBot.create(:entry_invitation,
        event: current_event, song: current_song_a, join_part: current_vocal,
        customer: experienced_customer, requested_by_customer: owner, sent_at: 1.hour.ago)

      post create_path, params: create_params([
        target(current_song_a, current_vocal, experienced_customer),
        target(current_song_b, current_vocal_b, experienced_customer)
      ])

      expect(flash[:notice]).to include "1件のエントリー依頼を送信しました"
      expect(flash[:notice]).to include "1件は送信済みのためスキップしました"
    end

    it "二重クリック（同一 POST を2回）でも配信は1通のみ" do
      params = create_params([target(current_song_a, current_vocal, experienced_customer)])

      perform_enqueued_jobs do
        post create_path, params: params
        post create_path, params: params
      end

      expect(EntryInvitation.where(customer_id: experienced_customer.id).count).to eq 1
      expect(ActionMailer::Base.deliveries.size).to eq 1
    end

    it "一般ユーザーの POST は拒否し、何も送信しない" do
      sign_in general_member

      expect {
        post create_path, params: create_params([target(current_song_a, current_vocal, experienced_customer)])
      }.not_to change(EntryInvitation, :count)

      expect(response).to redirect_to(public_event_path(current_event))
    end

    it "未ログインユーザーの POST は拒否する" do
      sign_out owner

      expect {
        post create_path, params: create_params([target(current_song_a, current_vocal, experienced_customer)])
      }.not_to change(EntryInvitation, :count)

      expect(response).to have_http_status(:found)
    end

    it "管理者は POST できる" do
      sign_in admin

      expect {
        post create_path, params: create_params([target(current_song_a, current_vocal, experienced_customer)])
      }.to change(EntryInvitation, :count).by(1)
    end

    it "終了済みイベントには送信できない" do
      travel_to(5.days.from_now) do
        expect {
          post create_path, params: create_params([target(current_song_a, current_vocal, experienced_customer)])
        }.not_to change(EntryInvitation, :count)
      end
    end

    it "有効な対象が 0 件ならイベント詳細へ戻す" do
      post create_path, params: create_params(["1:2:3", "abc"])

      expect(response).to redirect_to(public_event_path(current_event))
      expect(EntryInvitation.count).to eq 0
    end

    it "送信履歴（status/sent_at/各id/送信者）が保存される" do
      post create_path, params: create_params([target(current_song_a, current_vocal, experienced_customer)])

      invitation = EntryInvitation.last
      expect(invitation).to have_attributes(
        event_id: current_event.id, song_id: current_song_a.id, join_part_id: current_vocal.id,
        customer_id: experienced_customer.id, requested_by_customer_id: owner.id, status: "pending"
      )
      expect(invitation.sent_at).to be_present
    end
  end
end
