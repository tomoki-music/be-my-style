require "rails_helper"

RSpec.describe AdminNotificationMailer, type: :mailer do
  describe "#customer_feedback_created" do
    let(:admin) { create(:admin, email: "ops@example.com") }
    let(:customer) { create(:customer, name: "投稿者太郎", email: "poster@example.com") }
    let(:feedback) do
      create(:customer_feedback,
             customer: customer,
             category: :bug_report,
             subject: "検索が動かない",
             body: "1行目です\n2行目です")
    end

    let(:mail) { described_class.with(admin: admin, feedback: feedback).customer_feedback_created }

    it "件名にカテゴリー名が含まれること" do
      expect(mail.subject).to eq("【BeMyStyle】ご意見・ご相談BOXに新しい投稿がありました（アプリの不具合修正要望）")
    end

    it "宛先が管理者のメールアドレスであること" do
      expect(mail.to).to eq(["ops@example.com"])
    end

    it "本文に件名・投稿者名・投稿者メール・管理画面URLが含まれること" do
      body = mail.body.encoded

      expect(body).to include("検索が動かない")
      expect(body).to include("投稿者太郎")
      expect(body).to include("poster@example.com")
      expect(body).to include("http://localhost:3000/admin/customer_feedbacks/#{feedback.id}")
    end

    it "本文の改行が保持されること" do
      expect(mail.body.encoded).to match(%r{1行目です\s*<br\s*/?>\s*2行目です})
    end

    context "本文に危険なHTMLが含まれる場合" do
      let(:feedback) do
        create(:customer_feedback, customer: customer,
               body: "通常テキスト\n<script>alert('xss')</script>\n<img src=x onerror=alert(1)>")
      end

      it "scriptタグが実行可能な状態で出力されないこと" do
        body = mail.body.encoded

        expect(body).not_to include("<script>")
        expect(body).not_to include("onerror")
        expect(body).not_to include("alert(1)")
      end
    end
  end
end
