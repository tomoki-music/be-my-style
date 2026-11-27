require "rails_helper"

RSpec.describe AdminBulkMailDeliveryJob, type: :job do
  include ActiveJob::TestHelper

  let(:customer) { FactoryBot.create(:customer, name: "佐藤") }
  let(:bulk_mail) { AdminBulkMail.create!(subject: "{{name}}さんへ", body: "こんにちは {{name}} さん & <b>", request_token: "token-1", recipients_count: 1) }
  let(:recipient) { bulk_mail.recipients.create!(customer: customer, email_digest: AdminBulkMailRecipient.email_digest_for(customer.email)) }

  before { ActionMailer::Base.deliveries.clear }

  it "宛先1人に、名前を置き換えたプレーンテキストのメールを To 1件で送る" do
    described_class.perform_now(recipient.id)

    mail = ActionMailer::Base.deliveries.last
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(mail.to).to eq([customer.email])
    expect(mail.cc).to be_blank
    expect(mail.bcc).to be_blank
    expect(mail.subject).to eq("佐藤さんへ")
    expect(mail.content_type).to start_with("text/plain")
    expect(mail.body.decoded).to include("こんにちは 佐藤 さん & <b>")
    expect(recipient.reload).to be_sent
  end

  it "同じ宛先のジョブが再試行・二重投入されても2通目を送らない" do
    2.times { described_class.perform_now(recipient.id) }

    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it "送信中のまま止まった行は再送しない" do
    recipient.update!(status: :sending)

    described_class.perform_now(recipient.id)

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(recipient.reload).to be_sending
  end

  it "受付後に退会・メール通知オフになった人には送らず、送らなかったと記録する" do
    customer.update_column(:confirm_mail, false)

    described_class.perform_now(recipient.id)

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(recipient.reload).to be_skipped
    expect(recipient.failure_reason).to eq("メール通知を受け取らない設定")
  end

  it "確定後にメール未承認になった宛先には送らず、理由を送信履歴に残す" do
    recipient
    customer.update_columns(confirmed_at: nil)

    described_class.perform_now(recipient.id)

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(recipient.reload).to be_skipped
    expect(recipient.failure_reason).to eq("メール未承認のため除外")
  end

  it "確定後にアドレスが変わったら、確認画面に出ていない新しいアドレスへは送らない" do
    recipient
    customer.update_column(:email, "changed-after-confirm@example.com")

    described_class.perform_now(recipient.id)

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(recipient.reload).to be_skipped
    expect(recipient.failure_reason).to eq(AdminBulkMailRecipient::EMAIL_CHANGED_REASON)
  end

  it "送信中のまま止まった行は、一定時間後に「結果不明」として数え・表示する" do
    recipient.update!(status: :sending)
    recipient.update_column(:updated_at, AdminBulkMailRecipient::DELIVERY_UNKNOWN_AFTER.ago - 1.second)

    expect(recipient.reload.status_label).to start_with("結果不明")
    expect(bulk_mail.status_counts).to include("sending" => 0, "unknown" => 1)
  end

  it "送った後の記録で失敗したら「失敗」とせず送信中(結果不明)のまま残し、再送しない" do
    allow_any_instance_of(AdminBulkMailRecipient).to receive(:update!).and_raise(ActiveRecord::StatementInvalid)

    described_class.perform_now(recipient.id)
    described_class.perform_now(recipient.id)

    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(recipient.reload).to be_sending
  end

  it "debug レベルでも、ジョブと Action Mailer のログに宛先・件名・本文を出さない" do
    recipient
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output).tap { |l| l.level = :debug }
    loggers = [ActiveRecord::Base, ActionMailer::Base, ActiveJob::Base]
    originals = loggers.map(&:logger)
    original_rails_logger = Rails.logger
    begin
      loggers.each { |klass| klass.logger = logger }
      Rails.logger = logger
      described_class.perform_later(recipient.id)
      perform_enqueued_jobs
    ensure
      loggers.zip(originals).each { |klass, original| klass.logger = original }
      Rails.logger = original_rails_logger
    end

    expect(ActionMailer::Base.deliveries.size).to eq(1)
    log = output.string
    expect(log).to include("AdminBulkMailDeliveryJob")
    expect(log).not_to include(customer.email)
    expect(log).not_to include("佐藤さんへ")
    expect(log).not_to include("こんにちは")
  end

  it "送信に失敗したら失敗と記録し、例外を投げ直さない(アドレスはログ・理由に残さない)" do
    allow(AdminBulkMailer).to receive(:member_mail).and_raise(RuntimeError.new("550 #{customer.email} rejected"))
    logged = []
    allow(Rails.logger).to receive(:error) { |message| logged << message }

    expect { described_class.perform_now(recipient.id) }.not_to raise_error

    expect(recipient.reload).to be_failed
    expect(recipient.failure_reason).not_to include(customer.email)
    expect(logged.join).not_to include(customer.email)
  end
end
