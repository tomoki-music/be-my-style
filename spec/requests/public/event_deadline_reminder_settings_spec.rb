require "rails_helper"

RSpec.describe "イベントの締め切り自動リマインド設定", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:jst) { Time.find_zone("Asia/Tokyo") }
  let(:organizer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:member) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community, owner_id: organizer.id) }
  let(:event) do
    FactoryBot.create(
      :event, :event_with_songs,
      customer: organizer, community: community,
      event_name: "<script>alert('xss')</script>セッション",
      event_start_time: jst.parse("2026-10-25 18:00"),
      event_end_time: jst.parse("2026-10-25 21:00"),
      event_entry_deadline: jst.parse("2026-10-17 23:59"),
      request_deadline: nil
    )
  end

  before do
    travel_to(jst.parse("2026-10-17 08:00"))
    organizer.create_subscription!(status: "active", plan: "core")
    [organizer, member].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    ActionMailer::Base.deliveries.clear
  end

  after { travel_back }

  def reminder_params(entry: {}, request: {})
    {
      event: {
        deadline_reminders_attributes: {
          "0" => { kind: "request", enabled: "0", channel: "mail" }.merge(request),
          "1" => { kind: "entry", enabled: "0", channel: "mail" }.merge(entry)
        }
      }
    }
  end

  describe "編集画面" do
    before { sign_in organizer }

    it "初期状態は無効で、送信予定日時をJSTで表示すること" do
      get edit_public_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("曲リクエスト締め切りの自動リマインド", "エントリー締め切りの自動リマインド")
      expect(response.body).to include("2026年10月17日(土) 11:59")
      expect(response.body).to include("（日本時間 / JST）")
      expect(response.body).to include("5分ごとの定期処理")
      expect(response.body).not_to include('checked="checked" type="checkbox"')
    end

    it "プレビューのイベント名をエスケープして表示すること" do
      get edit_public_event_path(event)

      expect(response.body).to include("送信メッセージのプレビュー")
      expect(response.body).to include("&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;セッション")
      expect(response.body).not_to include("<script>alert('xss')</script>セッション")
    end

    it "プレビュー表示では送信も送信履歴の作成もしないこと" do
      event.update!(deadline_reminders_attributes: [{ kind: "entry", enabled: "1", channel: "chat" }])

      expect { get edit_public_event_path(event) }.not_to change(ChatMessage, :count)
      expect(ActionMailer::Base.deliveries).to be_empty
      expect(EventDeadlineReminderDelivery.count).to eq 0
    end
  end

  describe "更新" do
    it "主催者はエントリー締め切りのリマインドを有効化し、配信方法を選べること" do
      sign_in organizer

      put public_event_path(event), params: reminder_params(entry: { enabled: "1", channel: "chat" })

      reminder = event.deadline_reminders.find_by(kind: "entry")
      expect(response).to redirect_to(public_event_path(event))
      expect(reminder).to be_enabled
      expect(reminder).to be_channel_chat
      expect(reminder).to be_armed
      expect(event.deadline_reminders.find_by(kind: "request")).not_to be_enabled
    end

    it "締め切りが未設定のリクエストリマインドは有効化できずエラーを表示すること" do
      sign_in organizer

      put public_event_path(event), params: reminder_params(request: { enabled: "1" })

      expect(response.body).to include("曲リクエスト締め切りが未設定のため")
      expect(EventDeadlineReminder.where(enabled: true)).to be_empty
    end

    it "送信予定日時を過ぎてから有効化すると、自動送信しない理由を画面に表示すること" do
      travel_to(jst.parse("2026-10-17 13:00"))
      sign_in organizer
      put public_event_path(event), params: reminder_params(entry: { enabled: "1" })

      get edit_public_event_path(event)

      expect(response.body).to include("未送信（自動送信しません）")
      expect(response.body).to include("送信予定日時を過ぎているため、自動送信されません（送信予定日時を過ぎてから有効化されました）")
    end

    it "編集権限のない一般メンバーは設定を変更できないこと" do
      sign_in member

      put public_event_path(event), params: reminder_params(entry: { enabled: "1" })

      expect(response).to have_http_status(:found)
      expect(EventDeadlineReminder.count).to eq 0
    end

    it "他のイベントのリマインドIDを指定して書き換えられないこと" do
      other_event = FactoryBot.create(:event, :event_with_songs, customer: member, community: community,
                                                                  event_entry_deadline: jst.parse("2026-10-20 23:59"),
                                                                  event_start_time: jst.parse("2026-10-25 18:00"),
                                                                  event_end_time: jst.parse("2026-10-25 21:00"))
      other_event.update!(deadline_reminders_attributes: [{ kind: "entry", enabled: "1", channel: "mail" }])
      other_reminder = other_event.deadline_reminders.first
      sign_in organizer

      # nested attributes は自イベント配下以外のIDを RecordNotFound(本番では404)として拒否する。
      expect do
        put public_event_path(event), params: {
          event: { deadline_reminders_attributes: { "0" => { id: other_reminder.id, enabled: "0" } } }
        }
      end.to raise_error(ActiveRecord::RecordNotFound)
      expect(other_reminder.reload).to be_enabled
    end
  end

  describe "管理画面" do
    let(:admin) { FactoryBot.create(:admin) }

    it "管理者も設定を変更できること" do
      sign_in admin

      get edit_admin_event_path(event)
      expect(response.body).to include("エントリー締め切りの自動リマインド")

      put admin_event_path(event), params: reminder_params(entry: { enabled: "1", channel: "mail" })

      expect(event.deadline_reminders.find_by(kind: "entry")).to be_enabled
    end
  end
end
