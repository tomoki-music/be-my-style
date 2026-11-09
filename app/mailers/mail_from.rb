# 通知メールの From 表示名をプラットフォームごとに分ける。アドレスと送信経路はここでは変えない。
# - 音楽: 共通の Gmail SMTP 経路のまま（アドレスは ApplicationMailer の既定と同じ）。
# - ビジネス: CustomerMailer#business_mail では BusinessMail::SenderConfig が有効なとき info@be-my-style.jp に切り替わる。
# Devise・学習・管理者向けのメールは対象外で、ApplicationMailer の既定のまま。
module MailFrom
  LEGACY_ADDRESS = "from@example.com".freeze
  MUSIC_NAME = "BeMyStyle運営事務局".freeze
  BUSINESS_NAME = "NAKAMA運営事務局".freeze

  def self.music
    "#{MUSIC_NAME} <#{LEGACY_ADDRESS}>"
  end

  def self.business(address = LEGACY_ADDRESS)
    "#{BUSINESS_NAME} <#{address}>"
  end
end
