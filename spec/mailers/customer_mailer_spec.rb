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
  end
end
