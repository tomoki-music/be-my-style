require "rails_helper"

RSpec.describe "Admin::BulkMails", type: :request do
  include ActiveJob::TestHelper

  let(:admin) { FactoryBot.create(:admin) }
  let!(:alice) { FactoryBot.create(:customer, name: "アリス") }
  let!(:bob) { FactoryBot.create(:customer, name: "ボブ") }
  let!(:unconfirmed) { FactoryBot.create(:customer, name: "未承認さん").tap { |customer| customer.update_column(:confirmed_at, nil) } }
  let!(:withdrawn) { FactoryBot.create(:customer, name: "退会さん").tap { |customer| customer.update_column(:is_deleted, true) } }
  let(:selected_ids) { [alice.id, bob.id, unconfirmed.id, withdrawn.id] }

  def sign_in_admin
    # Admin::HomesController と同じく、ApplicationController の authenticate_customer! も通す必要がある。
    sign_in FactoryBot.create(:customer)
    sign_in admin
  end

  def preview_form(body)
    form = Nokogiri::HTML(body).css("form").find { |f| f["action"] == admin_bulk_mails_path }
    form.css("input[type=hidden]").to_h { |input| [input["name"], input["value"]] }
  end

  def post_preview
    post preview_admin_bulk_mails_path, params: {
      customer_ids: selected_ids.join(","), bulk_mail: { subject: "{{name}}さんへのお知らせ", body: "{{name}}さん\r\nこんにちは" }
    }
  end

  describe "管理者以外" do
    it "顧客としてログインしていても、作成・確認・送信・送信状況を拒否し、何も送らない" do
      sign_in FactoryBot.create(:customer)
      bulk_mail = AdminBulkMail.create!(subject: "s", body: "b", request_token: "existing")

      post compose_admin_bulk_mails_path, params: { customer_ids: alice.id.to_s }
      expect(response).to redirect_to(new_admin_session_path)
      post_preview
      expect(response).to redirect_to(new_admin_session_path)
      expect {
        post admin_bulk_mails_path, params: { customer_ids: alice.id.to_s, bulk_mail: { subject: "s", body: "b" }, request_token: "t", fingerprint: "f" }
      }.not_to change(AdminBulkMail, :count)
      expect(response).to redirect_to(new_admin_session_path)
      get admin_bulk_mail_path(bulk_mail)
      expect(response).to redirect_to(new_admin_session_path)
      expect(enqueued_jobs).to be_empty
    end
  end

  describe "管理者" do
    before { sign_in_admin }

    it "メンバー一覧に選択欄と「条件に一致した人をすべて選択」の対象 ID が出る" do
      get admin_homes_top_path, params: { email_confirmation: "unconfirmed" }

      doc = Nokogiri::HTML(response.body)
      expect(doc.css("[data-bulk-select-item]").map { |box| box["value"].to_i }).to include(unconfirmed.id)
      matching = JSON.parse(doc.at_css("[data-admin-bulk-select]")["data-matching-ids"])
      expect(matching).to include(unconfirmed.id)
      expect(matching).not_to include(alice.id, bob.id)
    end

    it "メンバーを選ばずに作成画面へ進むと一覧へ戻す" do
      post compose_admin_bulk_mails_path, params: { customer_ids: "" }

      expect(response).to redirect_to(admin_homes_top_path)
    end

    it "確認画面に送信対象・除外理由・未承認の件数・名前を置き換えたプレビューを出す" do
      post_preview

      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).to include("送信対象", "3件")
      expect(body).to include("退会済み：1件")
      doc = Nokogiri::HTML(body)
      expect(doc.at_css(".alert-warning").text.squish).to include("送信対象のうち 1件 はメールアドレスが未承認です")
      expect(doc.at_css(".admin-bulk-mail__preview").text).to include("アリスさんへのお知らせ", "アリスさん\nこんにちは")
      expect(body).not_to include("{{name}}さんへのお知らせ</")
    end

    it "件名が空なら確認画面へ進まず、作成画面に戻す" do
      post preview_admin_bulk_mails_path, params: { customer_ids: alice.id.to_s, bulk_mail: { subject: "", body: "本文" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("メンバーへのメール作成")
      expect(Nokogiri::HTML(response.body).at_css("textarea#bulk_mail_body").text.delete_prefix("\n")).to eq("本文")
    end

    it "選択した会員だけに、1人1通(To 1件)で名前入りのメールを送る" do
      unselected = FactoryBot.create(:customer)
      post_preview
      form = preview_form(response.body)

      perform_enqueued_jobs do
        post admin_bulk_mails_path, params: form.merge("email" => "attacker@example.com", "to" => "attacker@example.com")
      end

      bulk_mail = AdminBulkMail.last
      expect(response).to redirect_to(admin_bulk_mail_path(bulk_mail))
      mails = ActionMailer::Base.deliveries.last(3)
      expect(mails.map(&:to)).to contain_exactly([alice.email], [bob.email], [unconfirmed.email])
      expect(mails.map(&:subject)).to contain_exactly("アリスさんへのお知らせ", "ボブさんへのお知らせ", "未承認さんさんへのお知らせ")
      expect(ActionMailer::Base.deliveries.flat_map(&:to)).not_to include("attacker@example.com", unselected.email, withdrawn.email)
      expect(bulk_mail.status_counts).to include("sent" => 3, "failed" => 0)

      get admin_bulk_mail_path(bulk_mail)
      counts = Nokogiri::HTML(response.body).at_css("[data-bulk-mail-counts]").text.gsub(/\s+/, "")
      expect(counts).to include("受付3件", "送信成功3件", "失敗0件")
    end

    it "確定ボタンを二重に押しても(同じ token)、受け付けは1回で重複送信しない" do
      post_preview
      form = preview_form(response.body)

      perform_enqueued_jobs do
        post admin_bulk_mails_path, params: form
        post admin_bulk_mails_path, params: form
      end

      expect(AdminBulkMail.count).to eq(1)
      expect(AdminBulkMailRecipient.count).to eq(3)
      expect(ActionMailer::Base.deliveries.size).to eq(3)
      expect(response).to redirect_to(admin_bulk_mail_path(AdminBulkMail.last))
      follow_redirect!
      expect(response.body).to include("すでに受け付け済み")
    end

    it "確認後にアドレスや送信可否が変わったら送らずに確認画面を出し直す" do
      post_preview
      form = preview_form(response.body)
      bob.update_column(:email, "bob-new@example.com")
      alice.update_column(:confirm_mail, false)

      expect {
        post admin_bulk_mails_path, params: form
      }.not_to change(AdminBulkMail, :count)

      expect(response).to have_http_status(:conflict)
      expect(response.body).to include("送信対象(メールアドレス・メール承認・送信可否)が変わりました")
      expect(response.body).to include("メール通知を受け取らない設定：1件")
      expect(enqueued_jobs).to be_empty

      # 出し直した確認画面から確定すれば送れる
      perform_enqueued_jobs { post admin_bulk_mails_path, params: preview_form(response.body) }
      expect(ActionMailer::Base.deliveries.flat_map(&:to)).to contain_exactly("bob-new@example.com", unconfirmed.email)
    end

    it "確認画面の件名・本文を書き換えて確定しても送らない" do
      post_preview
      form = preview_form(response.body)

      post admin_bulk_mails_path, params: form.merge("bulk_mail[body]" => "差し替えた本文")

      expect(response).to have_http_status(:conflict)
      expect(AdminBulkMail.count).to eq(0)
    end

    it "debug レベルでも、リクエスト・SQL・ジョブ・メーラーのログにアドレス・件名・本文を出さない" do
      output = StringIO.new
      logger = ActiveSupport::Logger.new(output).tap { |l| l.level = :debug }
      loggers = [ActionController::Base, ActiveRecord::Base, ActionMailer::Base, ActiveJob::Base]
      originals = loggers.map(&:logger)
      original_rails_logger = Rails.logger
      begin
        loggers.each { |klass| klass.logger = logger }
        Rails.logger = logger
        post_preview
        perform_enqueued_jobs { post admin_bulk_mails_path, params: preview_form(response.body) }
      ensure
        loggers.zip(originals).each { |klass, original| klass.logger = original }
        Rails.logger = original_rails_logger
      end

      expect(ActionMailer::Base.deliveries.size).to eq(3)
      log = output.string
      expect(log).to include("Admin::BulkMailsController#create", "AdminBulkMailDeliveryJob")
      [alice.email, bob.email, unconfirmed.email, "お知らせ", "こんにちは"].each do |secret|
        expect(log).not_to include(secret)
      end
    end
  end
end
