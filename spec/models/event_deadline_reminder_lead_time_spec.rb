require "rails_helper"
require Rails.root.join("db/migrate/20261018000000_add_lead_hours_and_custom_message_to_event_deadline_reminders")

RSpec.describe EventDeadlineReminder, "送信タイミングと送信メッセージの編集", type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:jst) { Time.find_zone("Asia/Tokyo") }
  let(:owner) { FactoryBot.create(:customer) }
  let(:community) { FactoryBot.create(:community, owner_id: owner.id) }
  let(:event) do
    FactoryBot.create(
      :event, :event_with_songs,
      customer: owner, community: community,
      event_start_time: jst.parse("2026-10-25 18:00"),
      event_end_time: jst.parse("2026-10-25 21:00"),
      event_entry_deadline: jst.parse("2026-10-17 23:59"),
      request_deadline: jst.parse("2026-10-10 23:59")
    )
  end

  before { travel_to(jst.parse("2026-10-17 09:00")) }
  after { travel_back }

  def enable!(kind = "entry", **attributes)
    event.update!(deadline_reminders_attributes: [{ kind: kind, enabled: "1", channel: "mail" }.merge(attributes)])
    event.deadline_reminders.reload.detect { |reminder| reminder.kind == kind }
  end

  def update_reminder!(reminder, **attributes)
    event.update!(deadline_reminders_attributes: [{ id: reminder.id }.merge(attributes)])
    reminder.reload
  end

  describe "既存設定の引き継ぎ" do
    it "送信タイミングを指定しない行は12時間になること" do
      reminder = EventDeadlineReminder.create!(event: event, kind: "entry", channel: "mail")

      expect(reminder.lead_hours).to eq 12
      expect(reminder.custom_message).to be_nil
    end

    it "マイグレーションで既存の行は12時間として引き継ぎ、有効・送信状態を変えないこと" do
      armed = enable!("entry")
      sent = enable!("request")
      sent.update_columns(status: EventDeadlineReminder.statuses[:sent], sent_at: Time.current)
      migration = AddLeadHoursAndCustomMessageToEventDeadlineReminders.new

      ActiveRecord::Migration.suppress_messages do
        migration.migrate(:down)
        EventDeadlineReminder.reset_column_information
        # 導入前の状態(armed_deadline のみ記録)を再現してから up する。
        EventDeadlineReminder.where(id: armed.id).update_all(armed_deadline: event.event_entry_deadline)
        migration.migrate(:up)
      end
      EventDeadlineReminder.reset_column_information

      armed = EventDeadlineReminder.find(armed.id)
      sent = EventDeadlineReminder.find(sent.id)
      expect([armed.lead_hours, sent.lead_hours]).to eq [12, 12]
      expect(armed.armed_scheduled_at).to eq jst.parse("2026-10-17 11:59")
      expect(armed).to be_enabled
      expect(armed).to be_pending
      expect(armed).to be_armed
      expect(sent).to be_sent
      expect(sent).to be_enabled
    end
  end

  describe "送信タイミングの入力" do
    it "1時間と168時間(7日前)は保存できること" do
      reminder = enable!("entry", lead_hours: "1")
      expect(reminder.scheduled_at).to eq jst.parse("2026-10-17 22:59")
      expect(update_reminder!(reminder, lead_hours: "168").scheduled_at).to eq jst.parse("2026-10-10 23:59")
    end

    {
      "空欄" => "",
      "0" => "0",
      "負数" => "-3",
      "小数" => "1.5",
      "上限超過" => "169",
      "数字以外" => "abc"
    }.each do |label, value|
      it "#{label}(#{value.inspect})は保存できず、エラーを表示すること" do
        reminder = enable!("entry")

        result = event.update(deadline_reminders_attributes: [{ id: reminder.id, lead_hours: value }])

        expect(result).to eq false
        expect(event.errors.full_messages.join).to include("エントリー締め切りの自動リマインドの送信タイミング")
        expect(event.errors.full_messages).not_to include(a_string_starting_with("Deadline"))
        expect(reminder.reload.lead_hours).to eq 12
      end
    end

    it "小数は整数に丸めて保存しないこと(変換前の値で検証する)" do
      reminder = EventDeadlineReminder.new(event: event, kind: "entry", channel: "mail", lead_hours: "1.5")

      expect(reminder).not_to be_valid
      expect(reminder.errors.full_messages.join).to include("整数")
      expect(reminder.scheduled_at).to be_nil
    end

    it "種別ごとに個別に設定できること" do
      enable!("entry", lead_hours: "3")
      enable!("request", lead_hours: "48")

      expect(event.deadline_reminder_for(:entry).scheduled_at).to eq jst.parse("2026-10-17 20:59")
      expect(event.deadline_reminder_for(:request).scheduled_at).to eq jst.parse("2026-10-08 23:59")
    end

    it "JSTで日付をまたぐ送信予定日時を計算できること" do
      event.update!(event_entry_deadline: jst.parse("2026-10-18 09:30"))
      reminder = enable!("entry", lead_hours: "10")
      scheduled = reminder.scheduled_at.in_time_zone("Asia/Tokyo")

      expect([scheduled.to_date, scheduled.strftime("%H:%M")]).to eq [Date.new(2026, 10, 17), "23:30"]
    end
  end

  describe "送信タイミング変更時の送信予定" do
    it "未送信で新しい送信予定日時が未来なら、新しい日時に追従すること" do
      reminder = enable!("entry")
      reminder = update_reminder!(reminder, lead_hours: "6")

      expect(reminder).to be_armed
      expect(reminder.armed_scheduled_at).to eq jst.parse("2026-10-17 17:59")
    end

    it "変更で送信予定日時が現在以前になったら、自動送信せず理由を残すこと" do
      reminder = enable!("entry")
      reminder = update_reminder!(reminder, lead_hours: "20")

      expect(reminder).not_to be_armed
      expect(reminder).to be_disarmed_by_lead_time_changed_past
    end

    it "過去になった後に未来の時間へ戻せば、再び送信予定になること" do
      reminder = update_reminder!(enable!("entry"), lead_hours: "20")
      reminder = update_reminder!(reminder, lead_hours: "12")

      expect(reminder).to be_armed
      expect(reminder.disarm_reason).to be_nil
    end

    it "本文だけの変更では送信予定を維持すること(予定日時を過ぎた後の復旧送信も対象のまま)" do
      reminder = enable!("entry")
      travel_to(jst.parse("2026-10-17 13:00"))
      reminder = update_reminder!(reminder, custom_message: "本文だけ変更")

      expect(reminder).to be_armed
      expect(reminder.armed_scheduled_at).to eq jst.parse("2026-10-17 11:59")
      expect(reminder.custom_message).to eq "本文だけ変更"
    end

    it "送信済み・失敗のリマインドは時間や本文を変えても状態が変わらないこと" do
      reminder = enable!("entry")
      reminder.update_columns(status: EventDeadlineReminder.statuses[:sent])
      reminder = update_reminder!(reminder, lead_hours: "2", custom_message: "再送されない")

      expect(reminder).to be_sent
      expect(reminder.armed_scheduled_at).to eq jst.parse("2026-10-17 11:59")

      reminder.update_columns(status: EventDeadlineReminder.statuses[:failed])
      reminder = update_reminder!(reminder, lead_hours: "3")
      expect(reminder).to be_failed
    end
  end

  describe "送信中の設定変更" do
    it "送信タイミング・配信方法・メッセージは変更できないこと" do
      reminder = enable!("entry")
      reminder.update_columns(status: EventDeadlineReminder.statuses[:sending], started_at: Time.current)

      [{ lead_hours: "6" }, { channel: "chat" }, { custom_message: "途中で変更" }].each do |attributes|
        result = event.update(deadline_reminders_attributes: [{ id: reminder.id }.merge(attributes)])

        expect(result).to eq false
        expect(event.errors.full_messages.join).to include("送信中のため")
        event.reload
      end
      expect(reminder.reload.attributes.slice("lead_hours", "channel", "custom_message"))
        .to eq("lead_hours" => 12, "channel" => "mail", "custom_message" => nil)
    end

    it "無効化(送信の中断)はできること" do
      reminder = enable!("entry")
      reminder.update_columns(status: EventDeadlineReminder.statuses[:sending], started_at: Time.current)

      expect(update_reminder!(reminder, enabled: "0")).not_to be_enabled
    end
  end

  describe "送信メッセージの入力" do
    it "空白だけの入力は未設定(自動生成)として扱うこと" do
      reminder = enable!("entry", custom_message: " \n　 \r\n")

      expect(reminder.custom_message).to be_nil
      expect(reminder).not_to be_custom_message
    end

    it "改行・日本語・絵文字を保持し、改行コードはLFに揃えること" do
      reminder = enable!("entry", custom_message: "こんにちは🎸\r\n\r\n２行目です👍")

      expect(reminder.custom_message).to eq "こんにちは🎸\n\n２行目です👍"
    end

    it "5,000文字までは保存でき、超えるとサーバー側で拒否すること" do
      expect(enable!("entry", custom_message: "あ" * 5_000).custom_message.length).to eq 5_000

      result = event.update(deadline_reminders_attributes: [{ id: event.deadline_reminder_for(:entry).id, custom_message: "🎵" * 5_001 }])
      expect(result).to eq false
      expect(event.errors.full_messages.join).to include("5,000文字以内")
    end
  end
end
