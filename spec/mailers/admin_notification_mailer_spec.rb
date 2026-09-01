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

    it "通常の保存済み CustomerFeedback で件名生成が例外にならないこと" do
      expect { mail.subject }.not_to raise_error
    end

    it "宛先が管理者のメールアドレスであること" do
      expect(mail.to).to eq(["ops@example.com"])
    end

    it "本文に件名・カテゴリー日本語名・投稿者名・投稿者メールが含まれること" do
      body = mail.body.encoded

      expect(body).to include("検索が動かない")
      expect(body).to include("アプリの不具合修正要望")
      expect(body).to include("投稿者太郎")
      expect(body).to include("poster@example.com")
    end

    it "本文に投稿日時が含まれること" do
      feedback.update_columns(created_at: Time.zone.local(2026, 9, 1, 10, 30))
      expect(mail.body.encoded).to include("2026/09/01 10:30")
    end

    it "本文の管理画面URLが scheme + host を含む完全URLであること" do
      hrefs = Nokogiri::HTML(mail.body.encoded).css("a").map { |a| a["href"] }.compact
      expect(hrefs).to include("http://localhost:3000/admin/customer_feedbacks/#{feedback.id}")
    end

    it "管理者メモ(admin_note)は本文に含まれないこと" do
      feedback.update!(admin_note: "社内限定メモ・非公開情報")
      expect(mail.body.encoded).not_to include("社内限定メモ・非公開情報")
    end

    it "本文の改行が保持されること" do
      expect(mail.body.encoded).to match(%r{1行目です\s*<br\s*/?>\s*2行目です})
    end

    context "件名が未入力の場合" do
      let(:feedback) { create(:customer_feedback, customer: customer, subject: nil, body: "本文") }

      it "「（件名なし）」と表示されること" do
        expect(mail.body.encoded).to include("（件名なし）")
      end
    end

    context "本文に危険なHTMLが含まれる場合" do
      let(:feedback) do
        create(:customer_feedback, customer: customer,
               body: "通常テキスト\n<script>alert(\"x\")</script>\n<img src=x onerror=alert(1)>\n<a href=\"http://evil.example\">link</a>\n最終行")
      end

      it "ユーザー入力由来のタグは実体参照へエスケープされ、改行は保持されること" do
        body = mail.body.encoded

        # 実行・遷移し得る生タグが出力されない
        expect(body).not_to include("<script>")
        expect(body).not_to include("</script>")
        expect(body).not_to include("<img")
        expect(body).not_to include('href="http://evil.example"')

        # 本文由来のリンクは生成されない（管理画面リンクだけが唯一の <a>）
        anchor_hrefs = Nokogiri::HTML(body).css("a").map { |a| a["href"] }
        expect(anchor_hrefs).to eq(["http://localhost:3000/admin/customer_feedbacks/#{feedback.id}"])

        # 危険文字列はエスケープ済みテキストとして表示される
        expect(body).to include("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;")
        expect(body).to include("&lt;img src=x onerror=alert(1)&gt;")

        # 改行・通常テキストは保持される
        expect(body).to include("通常テキスト")
        expect(body).to include("最終行")
        expect(body).to match(%r{<br\s*/?>})
      end
    end
  end
end
