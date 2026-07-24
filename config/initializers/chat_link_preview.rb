# Chat内のURLリンクカード機能(Chat::LinkDetector)が「自ドメインのURL」と判定する
# ホスト一覧をここへ一元管理する。本番ドメインをサービスへ直接ハードコードしない。
Rails.application.config.x.chat_link_preview = ActiveSupport::OrderedOptions.new

Rails.application.config.x.chat_link_preview.internal_hosts =
  if ENV["CHAT_LINK_PREVIEW_INTERNAL_HOSTS"].present?
    ENV["CHAT_LINK_PREVIEW_INTERNAL_HOSTS"].split(",").map { |host| host.strip.downcase }
  else
    case Rails.env
    when "production"
      %w[be-my-style.com www.be-my-style.com]
    when "test"
      %w[www.example.com]
    else
      %w[localhost]
    end
  end.freeze
