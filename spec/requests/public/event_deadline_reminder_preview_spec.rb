require "rails_helper"

RSpec.describe "締め切り自動リマインドの送信タイミング・メッセージ編集とプレビュー", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:jst) { Time.find_zone("Asia/Tokyo") }
  let(:organizer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:member) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community, owner_id: organizer.id) }
  let(:event) do
    FactoryBot.create(
      :event, :event_with_songs,
      customer: organizer, community: community,
      event_name: "秋のセッション",
      event_start_time: jst.parse("2026-10-25 18:00"),
      event_end_time: jst.parse("2026-10-25 21:00"),
      event_entry_deadline: jst.parse("2026-10-17 23:59"),
      request_deadline: jst.parse("2026-10-18 09:30")
    )
  end
  let(:json_headers) { { "ACCEPT" => "application/json" } }

  before do
    travel_to(jst.parse("2026-10-17 08:00"))
    organizer.create_subscription!(status: "active", plan: "core")
    [organizer, member].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    ActionMailer::Base.deliveries.clear
  end

  after { travel_back }

  def preview(kind: "entry", reminder: {}, event_attributes: {}, path: deadline_reminder_preview_public_event_path(event))
    post path, params: { event: event_attributes, reminder: { kind: kind }.merge(reminder) }, headers: json_headers
  end

  def json
    JSON.parse(response.body)
  end

  # Rails は <textarea> 直後に改行を入れる(ブラウザは先頭の改行1つを無視する)。
  def textarea_value(page, id)
    page.at_css(id).text.delete_prefix("\n")
  end

  def reminder_params(entry: {}, request: {})
    {
      event: {
        deadline_reminders_attributes: {
          "0" => { kind: "request", enabled: "0", channel: "mail", lead_hours: "12", custom_message: "" }.merge(request),
          "1" => { kind: "entry", enabled: "0", channel: "mail", lead_hours: "12", custom_message: "" }.merge(entry)
        }
      }
    }
  end

  describe "編集画面" do
    before { sign_in organizer }

    it "種別ごとに送信タイミング(初期値12時間)とメッセージ欄・操作ボタンを表示すること" do
      get edit_public_event_path(event)

      page = Nokogiri::HTML(response.body)
      %w[request entry].each do |kind|
        input = page.at_css("#event_deadline_reminder_#{kind}_lead_hours")
        expect(input["value"]).to eq "12"
        expect([input["min"], input["max"], input["step"]]).to eq %w[1 168 1]
        expect(page.at_css("#event_deadline_reminder_#{kind}_custom_message")).to be_present
      end
      expect(response.body).to include("時間前に送信", "自動生成文を編集欄に入れる", "自動生成に戻す")
      expect(response.body).to include("編集欄の文章は自動では書き換わりません")
      expect(response.body).to include("共通フッター")
      expect(response.body).to include(deadline_reminder_preview_public_event_path(event))
    end

    it "保存した送信タイミングとカスタム本文を、開き直しても保持すること" do
      put public_event_path(event), params: reminder_params(entry: { enabled: "1", lead_hours: "6", custom_message: "絵文字🎸\n2行目" })
      expect(response).to redirect_to(public_event_path(event))

      get edit_public_event_path(event)

      page = Nokogiri::HTML(response.body)
      expect(page.at_css("#event_deadline_reminder_entry_lead_hours")["value"]).to eq "6"
      expect(textarea_value(page, "#event_deadline_reminder_entry_custom_message")).to eq "絵文字🎸\n2行目"
      expect(response.body).to include("2026年10月17日(土) 17:59")
    end

    it "入力エラー時も入力済みの文章と設定値を保持し、理由を表示すること" do
      put public_event_path(event), params: reminder_params(entry: { enabled: "1", lead_hours: "1.5", custom_message: "保持される本文" })

      page = Nokogiri::HTML(response.body)
      expect(page.at_css("#event_deadline_reminder_entry_lead_hours")["value"]).to eq "1.5"
      expect(textarea_value(page, "#event_deadline_reminder_entry_custom_message")).to eq "保持される本文"
      expect(response.body).to include("エントリー締め切りの自動リマインドの送信タイミングは整数で入力してください")
      expect(EventDeadlineReminder.where(enabled: true)).to be_empty
    end

    it "5,000文字を超える本文は保存せず、入力内容を保持すること" do
      put public_event_path(event), params: reminder_params(entry: { custom_message: "あ" * 5_001 })

      expect(response.body).to include("5,000文字以内")
      expect(textarea_value(Nokogiri::HTML(response.body), "#event_deadline_reminder_entry_custom_message").length).to eq 5_001
      expect(EventDeadlineReminder.where.not(custom_message: nil)).to be_empty
    end

    it "送信中は送信タイミング・配信方法・メッセージ欄を編集できない状態で表示すること" do
      event.update!(deadline_reminders_attributes: [{ kind: "entry", enabled: "1", channel: "mail" }])
      event.deadline_reminders.first.update_columns(status: EventDeadlineReminder.statuses[:sending], started_at: Time.current)

      get edit_public_event_path(event)

      page = Nokogiri::HTML(response.body)
      expect(page.at_css("#event_deadline_reminder_entry_lead_hours")["disabled"]).to be_present
      expect(page.at_css("#event_deadline_reminder_entry_custom_message")["disabled"]).to be_present
      expect(page.at_css("#event_deadline_reminder_entry_channel_chat")["disabled"]).to be_present
      expect(page.at_css("#event_deadline_reminder_entry_enabled")["disabled"]).to be_nil
      expect(response.body).to include("送信中のため、送信タイミング・配信方法・メッセージは変更できません")
    end

    it "送信済みなら、変更しても再送されないことを表示すること" do
      event.update!(deadline_reminders_attributes: [{ kind: "entry", enabled: "1", channel: "mail" }])
      event.deadline_reminders.first.update_columns(status: EventDeadlineReminder.statuses[:sent], sent_at: Time.current)

      get edit_public_event_path(event)

      expect(response.body).to include("送信済みのため、送信タイミングやメッセージを変更しても再送されません")
    end
  end

  describe "保存前プレビュー" do
    before { sign_in organizer }

    it "保存前の送信タイミングから送信予定日時をJSTで計算して返すこと(日付をまたぐ場合も)" do
      preview(kind: "request", reminder: { enabled: "1", lead_hours: "10" })

      expect(response).to have_http_status(:ok)
      expect(json["status_html"]).to include("2026年10月17日(土) 23:30", "（日本時間 / JST）", "未送信（送信予定）")
    end

    it "保存前に変更した締め切り日時も反映すること" do
      preview(reminder: { enabled: "1", lead_hours: "12" }, event_attributes: { event_entry_deadline: "2026-10-20T21:00" })

      expect(json["status_html"]).to include("2026年10月20日(火) 09:00")
    end

    it "予定日時が現在以前になる変更は、自動送信されない理由を表示すること" do
      event.update!(deadline_reminders_attributes: [{ kind: "entry", enabled: "1", channel: "mail" }])

      preview(reminder: { enabled: "1", lead_hours: "20" })

      expect(json["status_html"]).to include("未送信（自動送信しません）")
      expect(json["status_html"]).to include("送信予定日時を過ぎているため、自動送信されません（送信タイミングの変更で送信予定日時が過去になりました）")
    end

    it "不正な送信タイミングは理由を返すこと" do
      preview(reminder: { enabled: "1", lead_hours: "169" })

      expect(json["status_html"]).to include("送信タイミングを確認してください")
      expect(json["status_html"]).to include("1〜168時間の範囲で入力してください")
    end

    it "メール配信では件名・本文・共通フッターを、HTML風の文字列をエスケープして返すこと" do
      preview(reminder: { enabled: "1", channel: "mail", custom_message: "<script>alert(1)</script>\n🎸よろしく" })

      html = json["message_html"]
      expect(html).to include("配信方法：", "<strong>メール</strong>", "編集した文章")
      expect(html).to include("件名：", "【BeMyStyle】【本日締め切り🎸】秋のセッションのエントリー受付について")
      expect(html).to include("&lt;script&gt;alert(1)&lt;/script&gt;\n🎸よろしく")
      expect(html).not_to include("<script>")
      expect(html).to include("共通フッター（必ず付きます）", "https://be-my-style.com/public/events/#{event.id}")
    end

    it "チャット配信では、実際の投稿と同じ表示でプレビューすること" do
      preview(reminder: { enabled: "1", channel: "chat", custom_message: "# 見出しにしない\n<b>x</b>" })

      html = json["message_html"]
      expect(html).to include("<strong>コミュニティチャット</strong>", "自動お知らせ")
      expect(html).not_to include("件名：")
      expect(html).not_to include("<h1")
      expect(html).to include("&lt;b&gt;x&lt;/b&gt;")
      expect(html).to include(%(href="https://be-my-style.com/public/events/#{event.id}"))
    end

    it "編集欄に入れる用の自動生成文(フッターを含まない)を、保存前のイベント名で返すこと" do
      preview(reminder: { custom_message: "編集中" }, event_attributes: { event_name: "保存前の名前" })

      expect(json["auto_body"]).to include("「保存前の名前」のエントリーは")
      expect(json["auto_body"]).not_to include("https://be-my-style.com/public/events/")
      expect(event.reload.event_name).to eq "秋のセッション"
    end

    it "プレビューでは保存も送信もしないこと" do
      event.update!(deadline_reminders_attributes: [{ kind: "entry", enabled: "1", channel: "chat" }])
      reminder = event.deadline_reminders.first
      before_attributes = reminder.reload.attributes
      travel_to(jst.parse("2026-10-17 12:30"))

      expect do
        preview(reminder: { enabled: "1", channel: "mail", lead_hours: "1", custom_message: "保存されない" },
                event_attributes: { event_entry_deadline: "2026-10-30T23:59" })
      end.not_to change(ChatMessage, :count)

      expect(response).to have_http_status(:ok)
      expect(reminder.reload.attributes).to eq before_attributes
      expect(event.reload.event_entry_deadline).to eq jst.parse("2026-10-17 23:59")
      expect(EventDeadlineReminder.count).to eq 1
      expect(EventDeadlineReminderDelivery.count).to eq 0
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "作成中(未保存)のイベントでもプレビューできること" do
      preview(path: deadline_reminder_preview_public_events_path,
              reminder: { enabled: "1", lead_hours: "24" },
              event_attributes: { community_id: community.id, event_name: "新しいイベント",
                                  event_start_time: "2026-10-30T18:00", event_end_time: "2026-10-30T21:00",
                                  event_entry_deadline: "2026-10-29T23:59" })

      expect(response).to have_http_status(:ok)
      expect(json["status_html"]).to include("2026年10月28日(水) 23:59")
      expect(json["message_html"]).to include("新しいイベント", "（保存後に決まります）")
      expect(Event.where(event_name: "新しいイベント")).to be_empty
    end

    it "不正な種別は422を返すこと" do
      preview(kind: "bogus")

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "権限" do
    it "編集権限のない一般メンバーはプレビューできず、403になること" do
      sign_in member

      preview(reminder: { custom_message: "見せない" })

      expect(response).to have_http_status(:forbidden)
      expect(response.body).not_to include("見せない")
    end

    it "編集権限のない一般メンバーは送信タイミング・メッセージを変更できないこと" do
      event.update!(deadline_reminders_attributes: [{ kind: "entry", enabled: "1", channel: "mail" }])
      sign_in member

      put public_event_path(event), params: reminder_params(entry: { enabled: "1", lead_hours: "1", custom_message: "乗っ取り" })

      reminder = event.deadline_reminders.first.reload
      expect([reminder.lead_hours, reminder.custom_message]).to eq [12, nil]
    end

    it "未ログインではプレビューできないこと" do
      preview(reminder: { custom_message: "見せない" })

      expect(response).to have_http_status(:found)
      expect(response.body).not_to include("見せない")
    end

    it "作成権限のないコミュニティでは作成中プレビューもできないこと" do
      other_community = FactoryBot.create(:community, owner_id: FactoryBot.create(:customer).id)
      sign_in member

      preview(path: deadline_reminder_preview_public_events_path, event_attributes: { community_id: other_community.id })

      expect(response).to have_http_status(:forbidden)
    end

    it "一般会員は管理画面のプレビューを使えないこと" do
      sign_in organizer

      preview(path: deadline_reminder_preview_admin_event_path(event), reminder: { custom_message: "見せない" })

      expect(response.body).not_to include("見せない")
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "管理画面" do
    let(:admin) { FactoryBot.create(:admin) }

    before { sign_in admin }

    it "管理者は送信タイミングとメッセージを編集でき、プレビューも使えること" do
      get edit_admin_event_path(event)
      expect(response.body).to include(deadline_reminder_preview_admin_event_path(event), "時間前に送信")

      put admin_event_path(event), params: reminder_params(entry: { enabled: "1", lead_hours: "24", custom_message: "管理者が編集" })
      reminder = event.deadline_reminders.find_by(kind: "entry")
      expect([reminder.lead_hours, reminder.custom_message]).to eq [24, "管理者が編集"]
      expect(reminder).to be_disarmed_by_enabled_after_schedule

      preview(path: deadline_reminder_preview_admin_event_path(event), reminder: { lead_hours: "3" })
      expect(response).to have_http_status(:ok)
      expect(json["status_html"]).to include("2026年10月17日(土) 20:59")
    end
  end
end
