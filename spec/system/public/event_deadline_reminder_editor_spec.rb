require "rails_helper"

# 締め切り自動リマインド欄の画面操作(保存前プレビュー・自動生成文のコピー・自動生成に戻す)。
# プレビューは表示だけで、保存・送信はしないことも確認する。
RSpec.describe "締め切り自動リマインドの送信タイミング・メッセージ編集", type: :system, js: true do
  include EventDeadlineRemindersHelper

  let(:jst) { Time.find_zone("Asia/Tokyo") }
  let(:organizer) { create(:customer) }
  let(:community) { create(:community, owner_id: organizer.id) }
  let(:entry_deadline) { (jst.now + 3.days).change(hour: 23, min: 59) }
  let(:event) do
    create(
      :event, :event_with_songs,
      customer: organizer, community: community,
      event_name: "画面確認セッション",
      event_start_time: entry_deadline + 5.days,
      event_end_time: entry_deadline + 5.days + 3.hours,
      event_entry_deadline: entry_deadline,
      request_deadline: nil
    )
  end

  before do
    organizer.create_subscription!(status: "active", plan: "core")
    CommunityCustomer.create!(community: community, customer: organizer)
    event.update!(deadline_reminders_attributes: [{ kind: "entry", enabled: "1", channel: "mail" }])
  end

  def sign_in_via_form(customer)
    visit new_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def entry_item
    find(".deadline-reminder-settings__item--entry")
  end

  it "保存前に送信予定日時・プレビューが更新され、自動生成文のコピーと自動生成に戻す操作ができること" do
    sign_in_via_form(organizer)
    use_desktop_viewport
    visit edit_public_event_path(event)

    within(entry_item) do
      expect(page).to have_content(deadline_reminder_time(entry_deadline - 12.hours))

      fill_in "event_deadline_reminder_entry_lead_hours", with: "30"
      expect(page).to have_content(deadline_reminder_time(entry_deadline - 30.hours), wait: 10)

      find("summary", text: "送信メッセージのプレビュー").click
      expect(page).to have_content("自動生成", wait: 10)

      click_button "自動生成文を編集欄に入れる"
      expect(page).to have_field("event_deadline_reminder_entry_custom_message", with: /「画面確認セッション」のエントリーは/, wait: 10)
      textarea = find("#event_deadline_reminder_entry_custom_message")
      expect(textarea.value).not_to include("/public/events/")

      textarea.set("<b>太字にしない</b>\n参加お待ちしています🎸")
      expect(page).to have_css(".deadline-reminder-settings__preview-body", text: "<b>太字にしない</b>", wait: 10)
      expect(page).to have_content("編集した文章")
      # 絵文字も1文字として数える(サーバー側の上限判定と同じ数え方)。
      expect(page).to have_content("25 / 5,000文字")
      expect(page).to have_content("共通フッター（必ず付きます）")
      expect(page).to have_content("/public/events/#{event.id}")

      choose "event_deadline_reminder_entry_channel_chat"
      expect(page).to have_content("自動お知らせ」として", wait: 10)
      expect(page).not_to have_content("件名：")

      accept_confirm { click_button "自動生成に戻す" }
      expect(find("#event_deadline_reminder_entry_custom_message").value).to eq ""
      expect(page).to have_content(/本文：\s*自動生成/, wait: 10)
    end

    reminder = event.deadline_reminders.first.reload
    expect([reminder.lead_hours, reminder.custom_message, reminder.channel]).to eq [12, nil, "mail"]
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "スマートフォン幅でも設定欄が画面からはみ出さないこと" do
    sign_in_via_form(organizer)
    visit edit_public_event_path(event)
    use_mobile_viewport

    overflow = page.evaluate_script(<<~JS)
      (function () {
        var clientWidth = document.documentElement.clientWidth;
        var maxRight = 0;
        document.querySelectorAll('.deadline-reminder-settings__item, .deadline-reminder-settings__item textarea, .deadline-reminder-settings__item button').forEach(function (el) {
          maxRight = Math.max(maxRight, el.getBoundingClientRect().right);
        });
        return maxRight - clientWidth;
      })()
    JS
    expect(overflow).to be <= 1
  end
end
