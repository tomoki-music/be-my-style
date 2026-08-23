require "rails_helper"

RSpec.describe CustomerMailer, type: :mailer do
  describe "#mention_request_mail" do
    let(:poster) { create(:customer, name: "投稿者") }
    let(:mentioned_customer) { create(:customer, name: "メンション太郎") }
    let(:event) { create(:event, :event_with_songs, event_name: "テストイベント") }
    let(:request_record) { create(:request, customer: poster, event: event, request: "[@メンション太郎](customer:#{mentioned_customer.id})お願いします") }

    let(:mail) do
      described_class.with(
        ac_customer: poster,
        ps_customer: mentioned_customer,
        event_id: event.id,
        request: request_record
      ).mention_request_mail
    end

    it "件名にメンション通知であることが含まれること" do
      expect(mail.subject).to eq("【BeMyStyle】イベントリクエストでメンションされました")
    end

    it "宛先がメンションされたCustomerのメールアドレスであること" do
      expect(mail.to).to eq([mentioned_customer.email])
    end

    it "本文に投稿者名・イベント名・イベントURL・リクエスト内容が含まれること" do
      body = mail.body.encoded

      expect(body).to include(poster.name)
      expect(body).to include(event.event_name)
      expect(body).to include("https://be-my-style.com/public/events/#{event.id}")
      expect(body).to include(request_record.request)
    end

    context "リクエスト本文に複数行・危険なHTMLが含まれる場合" do
      let(:request_record) do
        create(:request, customer: poster, event: event,
               request: "1行目です\n2行目です\n\n<script>alert('xss')</script>\n<img src=x onerror=alert(1)>")
      end

      it "改行が保持されたまま表示される(simple_formatによる段落・brへの変換)" do
        body = mail.body.encoded

        expect(body).to match(%r{1行目です\r?\n<br\s*/?>\r?\n?2行目です})
      end

      it "scriptタグが実行可能な状態で出力されない" do
        body = mail.body.encoded

        expect(body).not_to include("<script>")
        expect(body).not_to include("</script>")
      end

      it "onerror等のイベント属性が除去される" do
        body = mail.body.encoded

        expect(body).not_to include("onerror")
        expect(body).not_to include("alert(1)")
      end
    end
  end

  describe "#request_msg_mail" do
    let(:poster) { create(:customer, name: "投稿者") }
    let(:recipient) { create(:customer, name: "参加者") }
    let(:event) { create(:event, :event_with_songs, event_name: "テストイベント") }
    let(:request_record) do
      create(:request, customer: poster, event: event,
             request: "1行目です\n2行目です\n\n<script>alert('xss')</script>\n<img src=x onerror=alert(1)>")
    end

    let(:mail) do
      described_class.with(
        ac_customer: poster,
        ps_customer: recipient,
        event_id: event.id,
        request: request_record
      ).request_msg_mail
    end

    it "件名にリクエスト通知であることが含まれること" do
      expect(mail.subject).to eq("参加したイベントにリクエストがありました！")
    end

    it "宛先が参加者のメールアドレスであること" do
      expect(mail.to).to eq([recipient.email])
    end

    it "改行が保持されたまま表示され、危険なHTMLが実行可能な状態で出力されない" do
      body = mail.body.encoded

      expect(body).to match(%r{1行目です\r?\n<br\s*/?>\r?\n?2行目です})
      expect(body).not_to include("<script>")
      expect(body).not_to include("</script>")
      expect(body).not_to include("onerror")
      expect(body).not_to include("alert(1)")
    end
  end
end
