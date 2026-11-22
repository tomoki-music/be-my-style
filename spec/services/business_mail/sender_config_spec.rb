require "rails_helper"

RSpec.describe BusinessMail::SenderConfig do
  let(:complete_env) do
    {
      "BUSINESS_MAIL_SENDER_ENABLED" => "true",
      "BUSINESS_SMTP_ADDRESS" => "sv00000.xserver.jp",
      "BUSINESS_SMTP_USER_NAME" => "info@be-my-style.jp",
      "BUSINESS_SMTP_PASSWORD" => "dummy-password"
    }
  end

  describe ".mail_options" do
    it "有効化フラグが無ければ従来どおり(空)になること" do
      expect(described_class.mail_options(complete_env.except("BUSINESS_MAIL_SENDER_ENABLED"))).to eq({})
    end

    it "有効化フラグが \"true\" 以外なら従来どおりになること" do
      %w[1 TRUE yes].each do |flag|
        expect(described_class.mail_options(complete_env.merge("BUSINESS_MAIL_SENDER_ENABLED" => flag))).to eq({})
      end
    end

    it "設定がそろっていれば From を info@be-my-style.jp にし、465番は接続開始時から TLS にすること" do
      options = described_class.mail_options(complete_env)

      expect(options[:from]).to eq("NAKAMA運営事務局 <info@be-my-style.jp>")
      expect(options[:delivery_method_options]).to include(
        address: "sv00000.xserver.jp",
        port: 465,
        domain: "be-my-style.jp",
        user_name: "info@be-my-style.jp",
        password: "dummy-password",
        authentication: :login,
        tls: true,
        ssl: true,
        enable_starttls: nil,
        enable_starttls_auto: nil,
        openssl_verify_mode: "peer"
      )
    end

    it "587番を指定したときは STARTTLS を必須にすること" do
      options = described_class.mail_options(complete_env.merge("BUSINESS_SMTP_PORT" => "587"))

      expect(options[:delivery_method_options]).to include(
        port: 587, tls: nil, ssl: nil, enable_starttls: true, enable_starttls_auto: nil
      )
    end

    it "ポートが数値でなければ 465 を使うこと" do
      options = described_class.mail_options(complete_env.merge("BUSINESS_SMTP_PORT" => "abc"))

      expect(options[:delivery_method_options]).to include(port: 465, tls: true)
    end

    it "必須設定が空文字・空白だけなら従来どおりにし、欠けたキー名だけをログに出すこと" do
      env = complete_env.merge("BUSINESS_SMTP_PASSWORD" => "", "BUSINESS_SMTP_ADDRESS" => "  ")
      allow(Rails.logger).to receive(:warn)

      expect(described_class.mail_options(env)).to eq({})
      expect(Rails.logger).to have_received(:warn).with(
        "[BusinessMail::SenderConfig] 設定不足のため従来の送信経路を使用 missing=BUSINESS_SMTP_ADDRESS,BUSINESS_SMTP_PASSWORD"
      )
    end

    it "ログに設定値(ユーザー名など)を含めないこと" do
      env = complete_env.except("BUSINESS_SMTP_PASSWORD")
      logged = []
      allow(Rails.logger).to receive(:warn) { |message| logged << message }

      described_class.mail_options(env)

      expect(logged.join).not_to include("info@be-my-style.jp")
      expect(logged.join).not_to include("sv00000")
    end
  end
end
