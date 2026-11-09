# ビジネス(NAKAMA)通知メールだけを info@be-my-style.jp から XServer SMTP 経由で送るための設定。
#
# - 共通の ActionMailer 設定(Gmail SMTP)・Devise・音楽/歌声/学習のメールには触れない。
#   CustomerMailer のビジネス通知だけが mail_options を mail に渡す。
# - BUSINESS_MAIL_SENDER_ENABLED="true"(厳密一致)で、SMTP 設定が全部そろったときだけ切り替える。
#   From と送信サーバーは必ず同時に切り替える(Gmail 経由で From だけ変えると SPF/DMARC で失敗するため)。
# - 有効化していても設定が欠けていれば従来の送信経路のまま送る(通知を止めない)。欠けたキー名だけをログに出す。
# - ENV は送信時(ジョブ実行時)に読む。本番はジョブが Puma 内で動くため、変更後は Puma の再起動が必要。
module BusinessMail
  class SenderConfig
    ENABLED_KEY = "BUSINESS_MAIL_SENDER_ENABLED".freeze
    ADDRESS_KEY = "BUSINESS_SMTP_ADDRESS".freeze
    PORT_KEY = "BUSINESS_SMTP_PORT".freeze
    USER_NAME_KEY = "BUSINESS_SMTP_USER_NAME".freeze
    PASSWORD_KEY = "BUSINESS_SMTP_PASSWORD".freeze
    REQUIRED_KEYS = [ADDRESS_KEY, USER_NAME_KEY, PASSWORD_KEY].freeze

    FROM_ADDRESS = "info@be-my-style.jp".freeze
    FROM = MailFrom.business(FROM_ADDRESS).freeze
    HELO_DOMAIN = "be-my-style.jp".freeze
    DEFAULT_PORT = 465
    LOG_TAG = "[BusinessMail::SenderConfig]".freeze

    def self.mail_options(env = ENV)
      new(env).mail_options
    end

    def initialize(env)
      @env = env
    end

    # mail(...) に merge するオプション。無効時は {} を返し、従来どおりの From・送信経路になる。
    def mail_options
      return {} unless enabled?

      missing = REQUIRED_KEYS.select { |key| value(key).nil? }
      if missing.any?
        Rails.logger.warn("#{LOG_TAG} 設定不足のため従来の送信経路を使用 missing=#{missing.join(',')}")
        return {}
      end

      { from: FROM, delivery_method_options: smtp_settings }
    end

    private

    def enabled?
      @env[ENABLED_KEY] == "true"
    end

    # delivery_method_options は共通の smtp_settings(Gmail)に上書き merge されるため、
    # Gmail 側の値が残らないよう全キーを明示する。
    def smtp_settings
      port = smtp_port
      implicit_tls = port == 465
      {
        address: value(ADDRESS_KEY),
        port: port,
        domain: HELO_DOMAIN,
        user_name: value(USER_NAME_KEY),
        password: value(PASSWORD_KEY),
        authentication: :login,
        # 465 は接続開始時から TLS、それ以外は STARTTLS を必須にする。
        # mail gem は tls/ssl が nil 以外だと STARTTLS 設定を見ないため、STARTTLS 側では nil にする。
        tls: implicit_tls ? true : nil,
        ssl: implicit_tls ? true : nil,
        enable_starttls: implicit_tls ? nil : true,
        enable_starttls_auto: nil,
        # 共通設定(Gmail)の openssl_verify_mode: 'none' を引き継がず、証明書を検証する。
        openssl_verify_mode: "peer"
      }
    end

    def smtp_port
      raw = value(PORT_KEY)
      return DEFAULT_PORT if raw.nil?

      Integer(raw, 10)
    rescue ArgumentError
      DEFAULT_PORT
    end

    # systemd の `Environment=KEY=` は空文字になるため、空白のみも未設定として扱う。
    def value(key)
      raw = @env[key].to_s.strip
      raw.empty? ? nil : raw
    end
  end
end
