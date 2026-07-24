module Chat
  # Chat::LinkDetectorが「自ドメインのURL」と判定するホスト一覧を、環境変数と環境別
  # デフォルトから算出する。config/initializers/chat_link_preview.rbから呼ばれ、
  # Rails.application.config.x.chat_link_preview.internal_hostsへ格納する値を作る。
  #
  # 開発環境では、本番URL(be-my-style.com/www.be-my-style.com)をそのまま貼って
  # 動作確認できるよう、localhostに加えて本番ホストも許可する。test環境は既存の
  # System/Request specが使うwww.example.comのみを許可し、production/testのホストを
  # 混入させない。
  module LinkPreviewHostConfig
    DEFAULT_HOSTS_BY_ENV = {
      "production" => %w[be-my-style.com www.be-my-style.com],
      "test" => %w[www.example.com]
    }.freeze
    DEVELOPMENT_DEFAULT_HOSTS = %w[be-my-style.com www.be-my-style.com localhost].freeze

    def self.resolve(env_value:, rails_env:)
      configured = normalize(env_value)
      configured.presence || default_hosts_for(rails_env)
    end

    def self.default_hosts_for(rails_env)
      normalize(DEFAULT_HOSTS_BY_ENV.fetch(rails_env.to_s, DEVELOPMENT_DEFAULT_HOSTS))
    end

    # 空文字・前後の空白・大文字小文字違い・重複を安全に取り除く。
    # nilや空配列が渡ってもArray(...)で空配列として扱い、例外は発生させない。
    def self.normalize(value)
      hosts = value.is_a?(String) ? value.split(",") : Array(value)
      hosts.map { |host| host.to_s.strip.downcase }.reject(&:blank?).uniq
    end
  end
end
