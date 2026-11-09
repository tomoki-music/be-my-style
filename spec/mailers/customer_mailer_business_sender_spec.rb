require "rails_helper"

# ビジネス通知だけが info@be-my-style.jp(XServer SMTP)に切り替わり、
# 音楽の通知・Devise のメールは従来の送信元・送信経路のままであることを確認する。
RSpec.describe "ビジネス通知メールの送信元切り替え", type: :mailer do
  include ActiveJob::TestHelper

  let(:sender) { create(:customer, name: "送信者") }
  let(:recipient) { create(:customer, name: "受信者") }
  let(:community) { create(:community, owner_id: sender.id, domain: Domain.find_or_create_by!(name: "business")) }
  let(:legacy_from) { ["from@example.com"] }
  let(:business_env) do
    {
      "BUSINESS_MAIL_SENDER_ENABLED" => "true",
      "BUSINESS_SMTP_ADDRESS" => "sv00000.xserver.jp",
      "BUSINESS_SMTP_USER_NAME" => "info@be-my-style.jp",
      "BUSINESS_SMTP_PASSWORD" => "dummy-password"
    }
  end

  def stub_env(values)
    allow(ENV).to receive(:[]).and_call_original
    values.each { |key, value| allow(ENV).to receive(:[]).with(key).and_return(value) }
  end

  def business_mails
    {
      business_follow_mail: CustomerMailer.with(ac_customer: sender, ps_customer: recipient).business_follow_mail,
      business_request_mail: CustomerMailer.with(ac_customer: sender, ps_customer: recipient, community: community)
                                           .business_request_mail,
      business_accept_mail: CustomerMailer.with(ac_customer: sender, ps_customer: recipient, community: community)
                                          .business_accept_mail
    }
  end

  context "切り替えが無効なとき" do
    before { stub_env("BUSINESS_MAIL_SENDER_ENABLED" => nil) }

    it "ビジネス通知の From・送信設定は従来どおりであること" do
      business_mails.each do |name, mail|
        expect(mail.from).to eq(legacy_from), name.to_s
        expect(mail.delivery_method.settings).not_to include(:tls), name.to_s
      end
    end
  end

  context "切り替えが有効で設定がそろっているとき" do
    before { stub_env(business_env) }

    it "ビジネス通知の From が info@be-my-style.jp になり、XServer へ 465番の TLS で送ること" do
      business_mails.each do |name, mail|
        expect(mail.from).to eq(["info@be-my-style.jp"]), name.to_s
        expect(mail[:from].display_names).to eq(["管理人より"]), name.to_s
        expect(mail.reply_to).to be_nil, name.to_s
        expect(mail.delivery_method.settings).to include(
          address: "sv00000.xserver.jp", port: 465, tls: true, openssl_verify_mode: "peer"
        ), name.to_s
      end
    end

    it "宛先・件名・本文は切り替え前と変わらないこと" do
      mail = business_mails[:business_request_mail]

      expect(mail.to).to eq([recipient.email])
      expect(mail.subject).to eq("あなたの企画した「コミュニティ」へ参加申請が届きました！")
      expect(mail.body.encoded).to include("https://be-my-style.com/business/communities/#{community.id}")
    end

    it "deliver_later でもジョブ実行時に新しい送信元で送ること" do
      ActionMailer::Base.deliveries.clear
      perform_enqueued_jobs do
        CustomerMailer.with(ac_customer: sender, ps_customer: recipient).business_follow_mail.deliver_later
      end

      delivered = ActionMailer::Base.deliveries.last
      expect(delivered.from).to eq(["info@be-my-style.jp"])
      expect(delivered.to).to eq([recipient.email])
    end

    it "音楽の通知は従来の From・送信設定のままであること" do
      mail = CustomerMailer.with(ac_customer: sender, ps_customer: recipient).create_follow_mail

      expect(mail.from).to eq(legacy_from)
      expect(mail.delivery_method.settings).not_to include(:tls)
    end

    it "Devise のパスワード再設定メールは送信元が変わらないこと" do
      mail = Devise::Mailer.reset_password_instructions(recipient, "dummy-token")

      expect(mail.from).not_to include("info@be-my-style.jp")
      expect(mail.delivery_method.settings).not_to include(:tls)
    end
  end

  context "切り替えが有効でも設定が欠けているとき" do
    before { stub_env(business_env.merge("BUSINESS_SMTP_PASSWORD" => "")) }

    it "通知を止めず従来の From・送信設定で作ること" do
      mail = business_mails[:business_follow_mail]

      expect(mail.from).to eq(legacy_from)
      expect(mail.delivery_method.settings).not_to include(:tls)
    end
  end
end
