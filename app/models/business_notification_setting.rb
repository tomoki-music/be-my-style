# Business(NAKAMA)の通知設定。本人がマイページの「通知設定」で変更する。
# 音楽側の customers.confirm_mail とは別に持つ(Business 側の変更を音楽側へ波及させない)。
# 行が無い会員の既定値は Customer#business_notification_setting_or_default を参照。
class BusinessNotificationSetting < ApplicationRecord
  belongs_to :customer

  validates :customer_id, uniqueness: true
  validates :email_enabled, :in_app_enabled, inclusion: { in: [true, false] }
end
