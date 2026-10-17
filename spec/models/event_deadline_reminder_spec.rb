require "rails_helper"

RSpec.describe EventDeadlineReminder, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:owner) { FactoryBot.create(:customer) }
  let(:community) { FactoryBot.create(:community, owner_id: owner.id) }
  let(:now) { Time.zone.parse("2026-10-17 09:00") }
  let(:event) do
    FactoryBot.create(
      :event, :event_with_songs,
      customer: owner, community: community,
      event_start_time: Time.zone.parse("2026-10-25 18:00"),
      event_end_time: Time.zone.parse("2026-10-25 21:00"),
      event_entry_deadline: Time.zone.parse("2026-10-17 23:59"),
      request_deadline: Time.zone.parse("2026-10-10 23:59")
    )
  end

  around { |example| travel_to(now) { example.run } }

  def enable!(kind, channel: "mail")
    event.update!(deadline_reminders_attributes: [{ kind: kind, enabled: "1", channel: channel }])
    event.deadline_reminders.reload.detect { |reminder| reminder.kind == kind }
  end

  describe "#scheduled_at" do
    it "締め切りの12時間前(Asia/Tokyo)になること" do
      reminder = event.deadline_reminder_for(:entry)

      expect(reminder.scheduled_at).to eq Time.find_zone("Asia/Tokyo").parse("2026-10-17 11:59")
    end

    it "締め切りが午前中なら送信予定はJSTで前日になること" do
      event.update!(event_entry_deadline: Time.zone.parse("2026-10-18 09:30"))
      scheduled = event.deadline_reminder_for(:entry).scheduled_at.in_time_zone("Asia/Tokyo")

      expect([scheduled.to_date, scheduled.strftime("%H:%M")]).to eq [Date.new(2026, 10, 17), "21:30"]
    end

    it "締め切りが未設定ならnilになること" do
      event.update!(request_deadline: nil)

      expect(event.deadline_reminder_for(:request).scheduled_at).to be_nil
    end
  end

  describe "初期状態" do
    it "既存イベントにはリマインド行が無く、フォーム用の設定は無効・メールになること" do
      reminders = event.deadline_reminders_for_form

      expect(EventDeadlineReminder.count).to eq 0
      expect(reminders.map(&:enabled?)).to eq [false, false]
      expect(reminders.map(&:channel)).to eq %w[mail mail]
    end
  end

  describe "有効化と送信予定(armed)" do
    it "送信予定日時より前に有効化すると現在の締め切りで送信待ちになること" do
      reminder = enable!("entry")

      expect(reminder).to be_armed
      expect(reminder.armed_deadline).to eq event.event_entry_deadline
      expect(reminder.disarm_reason).to be_nil
    end

    it "送信予定日時を過ぎてから有効化すると自動送信しないこと" do
      travel_to(Time.zone.parse("2026-10-17 12:30"))
      reminder = enable!("entry")

      expect(reminder).not_to be_armed
      expect(reminder).to be_disarmed_by_enabled_after_schedule
    end

    it "締め切りが未設定の種別は有効にできないこと" do
      event.update!(request_deadline: nil)

      result = event.update(deadline_reminders_attributes: [{ kind: "request", enabled: "1", channel: "mail" }])

      expect(result).to eq false
      expect(event.errors.full_messages.join).to include("曲リクエスト締め切りが未設定")
    end

    it "有効なまま締め切りを削除することはできないこと" do
      reminder = enable!("entry")
      reminder.event.event_entry_deadline = nil

      expect(reminder.event).not_to be_valid
    end

    it "無効化すると送信待ちが解除されること" do
      reminder = enable!("entry")
      event.update!(deadline_reminders_attributes: [{ id: reminder.id, enabled: "0" }])

      expect(reminder.reload).not_to be_armed
      expect(reminder.armed_deadline).to be_nil
    end

    it "同じ種別を2件作れないこと" do
      enable!("entry")
      duplicate = EventDeadlineReminder.new(event: event, kind: "entry", channel: "mail")

      expect(duplicate).not_to be_valid
    end
  end

  describe "締め切り変更への追従" do
    it "送信予定が未来になる変更なら新しい締め切りで送信待ちになること" do
      reminder = enable!("entry")
      new_deadline = Time.zone.parse("2026-10-20 20:00")
      event.update!(event_entry_deadline: new_deadline)

      expect(reminder.reload.armed_deadline).to eq new_deadline
      expect(reminder.scheduled_at).to eq Time.zone.parse("2026-10-20 08:00")
    end

    it "送信予定が過去になる変更なら自動送信せず理由を残すこと" do
      reminder = enable!("entry")
      event.update!(event_entry_deadline: Time.zone.parse("2026-10-17 20:00"))

      expect(reminder.reload).not_to be_armed
      expect(reminder).to be_disarmed_by_deadline_changed_past
    end

    it "送信予定日時を過ぎた後に別項目を編集しても、送信待ちは解除されないこと(停止からの復旧送信のため)" do
      reminder = enable!("entry")
      travel_to(Time.zone.parse("2026-10-17 13:00"))
      event.update!(event_name: "名前だけ変更")

      expect(reminder.reload).to be_armed
    end

    it "送信済みのリマインドは締め切りや設定を変えても状態が変わらないこと" do
      reminder = enable!("entry")
      reminder.update_columns(status: EventDeadlineReminder.statuses[:sent])
      event.update!(event_entry_deadline: Time.zone.parse("2026-10-20 20:00"))
      event.update!(deadline_reminders_attributes: [{ id: reminder.id, channel: "chat" }])

      reminder.reload
      expect(reminder).to be_sent
      expect(reminder.armed_deadline).to eq Time.zone.parse("2026-10-17 23:59")
    end
  end

  describe "不正な入力" do
    it "想定外の配信方法・種別は例外ではなく検証エラーになること" do
      reminder = EventDeadlineReminder.new(event: event, kind: "bogus", channel: "sms")

      expect(reminder).not_to be_valid
      expect(reminder.errors[:kind]).to be_present
      expect(reminder.errors[:channel]).to be_present
    end

    it "既存の種別は変更できないこと" do
      reminder = enable!("entry")
      reminder.kind = "request"

      expect(reminder).not_to be_valid
    end
  end

  it "イベントを削除するとリマインドと送信履歴も削除されること" do
    reminder = enable!("entry")
    reminder.deliveries.create!(customer: owner, status: :delivered)

    expect { event.destroy }.to change(EventDeadlineReminder, :count).by(-1)
      .and change(EventDeadlineReminderDelivery, :count).by(-1)
  end
end
