require "rails_helper"

RSpec.describe EventDeadlineReminderMailer, type: :mailer do
  let(:jst) { Time.find_zone("Asia/Tokyo") }
  let(:recipient) { FactoryBot.create(:customer, name: "受信 太郎") }
  let(:community) { FactoryBot.create(:community, owner_id: recipient.id, name: "MMM") }
  let(:event) do
    FactoryBot.create(
      :event, :event_with_songs,
      customer: recipient, community: community,
      event_name: "<b>太字</b>セッション",
      event_start_time: jst.parse("2026-10-25 18:00"),
      event_end_time: jst.parse("2026-10-25 21:00"),
      event_entry_deadline: jst.parse("2026-10-17 23:59")
    )
  end
  let(:reminder) { EventDeadlineReminder.create!(event: event, kind: "entry", channel: "mail") }
  let(:delivery) { reminder.deliveries.create!(customer: recipient, status: :sending) }
  let(:message) { EventDeadlineReminders::MessageBuilder.call(event: event, kind: "entry", sent_at: jst.parse("2026-10-17 11:59")) }
  let(:mail) { described_class.with(delivery: delivery, message: message).remind }

  it "受信者本人だけを宛先にし、件名に締め切り種別を含めること" do
    expect(mail.to).to eq [recipient.email]
    expect(mail.cc).to be_blank
    expect(mail.bcc).to be_blank
    expect(mail.subject).to eq "【BeMyStyle】【本日締め切り🎸】<b>太字</b>セッションのエントリー受付について"
  end

  it "本文のイベント名をHTMLエスケープし、イベントURLをリンクにすること" do
    body = mail.body.encoded

    expect(body).to include("&lt;b&gt;太字&lt;/b&gt;セッション")
    expect(body).not_to include("<b>太字</b>")
    expect(body).to include(%(href="https://be-my-style.com/public/events/#{event.id}"))
    expect(body).to include("コミュニティ「MMM」のメンバー")
  end

  it "カスタム本文の改行・絵文字を保持し、HTML風の文字列をエスケープして、共通フッターのURLをリンクにすること" do
    custom_message = EventDeadlineReminders::MessageBuilder.call(
      event: event, kind: "entry", sent_at: jst.parse("2026-10-17 11:59"),
      custom_message: "1行目🎸\n<a href=\"https://evil.example\">罠</a>\n3行目"
    )
    body = described_class.with(delivery: delivery, message: custom_message).remind.body.encoded

    expect(body).to match(%r{1行目🎸\s*<br>\s*&lt;a href=})
    expect(body).to include("&lt;a href=&quot;https://evil.example&quot;&gt;罠&lt;/a&gt;")
    expect(body).not_to include('href="https://evil.example"')
    expect(body).to include("▼イベント詳細・エントリーはこちら")
    expect(body).to include(%(href="https://be-my-style.com/public/events/#{event.id}"))
  end
end
