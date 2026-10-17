require "rails_helper"

RSpec.describe EventDeadlineReminders::MessageBuilder do
  let(:jst) { Time.find_zone("Asia/Tokyo") }
  let(:event) do
    FactoryBot.create(
      :event, :event_with_songs,
      event_name: "秋のMMMセッション",
      place: "MMMスタジオ",
      entrance_fee: 1500,
      event_start_time: jst.parse("2026-10-25 18:00"),
      event_end_time: jst.parse("2026-10-25 21:00"),
      event_entry_deadline: jst.parse("2026-10-17 23:59"),
      request_deadline: jst.parse("2026-10-10 12:00")
    )
  end

  def build(kind:, sent_at:)
    described_class.call(event: event, kind: kind, sent_at: sent_at)
  end

  describe "エントリー締め切り" do
    subject(:message) { build(kind: :entry, sent_at: jst.parse("2026-10-17 11:59")) }

    it "送信日と締め切り日が同じなら「本日」を使うこと" do
      expect(message.subject).to eq "【本日締め切り🎸】秋のMMMセッションのエントリー受付について"
      expect(message.body).to include("10月25日(日)開催「秋のMMMセッション」のエントリーは、本日10月17日(土) 23:59までです🎵")
    end

    it "イベント情報と参加方法・絶対URLを含むこと" do
      expect(message.body).to include("📅 開催日時：10月25日(日) 18:00〜21:00")
      expect(message.body).to include("📍 会場：MMMスタジオ")
      expect(message.body).to include("💰 参加費：1,500円")
      expect(message.body).to include("⏰ エントリー締め切り：10月17日(土) 23:59")
      expect(message.body).to include("「参加確認画面へ」→「参加する」でエントリー")
      expect(message.body).to include("https://be-my-style.com/public/events/#{event.id}")
    end
  end

  describe "曲リクエスト締め切り" do
    subject(:message) { build(kind: :request, sent_at: jst.parse("2026-10-10 00:00")) }

    it "リクエストを促す文面に切り替わること" do
      expect(message.subject).to eq "【本日締め切り🎵】秋のMMMセッションの曲リクエスト受付について"
      expect(message.body).to include("曲リクエストは、本日10月10日(土) 12:00までです")
      expect(message.body).to include("「みんなのリクエスト」欄から")
      expect(message.body).to include("▼イベント詳細・リクエストはこちら")
      expect(message.body).not_to include("参加確認画面へ")
    end
  end

  describe "JSTの日付境界" do
    it "締め切り日が送信日の翌日なら「明日」になること" do
      event.update!(event_entry_deadline: jst.parse("2026-10-18 09:30"))
      message = build(kind: :entry, sent_at: jst.parse("2026-10-17 21:30"))

      expect(message.subject).to start_with("【明日締め切り🎸】")
      expect(message.body).to include("明日10月18日(日) 09:30まで")
    end

    it "UTCでは同日でもJSTで日付が異なれば「本日」にしないこと" do
      event.update!(event_entry_deadline: jst.parse("2026-10-18 08:00"))
      # 2026-10-17 20:00 JST = 2026-10-17 11:00 UTC、締め切りは 2026-10-17 23:00 UTC
      message = build(kind: :entry, sent_at: Time.utc(2026, 10, 17, 11, 0))

      expect(message.subject).to start_with("【明日締め切り🎸】")
    end

    it "送信が遅れて締め切り日と2日以上離れても「本日」「明日」を使わないこと" do
      message = build(kind: :entry, sent_at: jst.parse("2026-10-15 10:00"))

      expect(message.subject).to start_with("【締め切りのお知らせ🎸】")
      expect(message.body).not_to include("本日")
    end
  end

  it "日をまたぐイベントは終了日も表示すること" do
    event.update!(event_end_time: jst.parse("2026-10-26 02:00"))

    expect(build(kind: :entry, sent_at: jst.parse("2026-10-17 11:59")).body)
      .to include("10月25日(日) 18:00〜10月26日(月) 02:00")
  end

  it "未設定の会場は推測で補わず行ごと省略すること" do
    event.place = ""

    expect(build(kind: :entry, sent_at: jst.parse("2026-10-17 11:59")).body).not_to include("📍")
  end

  it "イベント説明(introduction)は文面に含めないこと" do
    event.update!(introduction: "<script>alert(1)</script>説明文")

    message = build(kind: :entry, sent_at: jst.parse("2026-10-17 11:59"))
    expect(message.body).not_to include("説明文")
  end

  describe "チャット用本文" do
    it "イベント名中のMarkdown記号をエスケープし、表示時にHTMLが無害化されること" do
      event.update!(event_name: "**太字**と[リンク](javascript:alert(1))<img src=x onerror=alert(1)>")
      message = build(kind: :entry, sent_at: jst.parse("2026-10-17 11:59"))

      expect(message.chat_body).to include("\\*\\*太字\\*\\*")
      html = Chat::MarkdownRenderer.call(message.chat_body)
      expect(html).not_to include("<img")
      expect(html).not_to include('href="javascript')
      expect(html).not_to include("<strong>太字</strong>")
    end

    it "件名を太字の1行目として含むこと" do
      message = build(kind: :entry, sent_at: jst.parse("2026-10-17 11:59"))

      expect(message.chat_body.lines.first.strip).to start_with("**【本日締め切り🎸】")
    end
  end
end
