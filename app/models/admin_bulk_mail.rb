# 管理画面 TOP のメンバー一覧から送る「名前入り一括メール」1回分。
# 宛先ごとの配信状態は AdminBulkMailRecipient に持つ(メールアドレスは保存せず、送る直前に会員から読む)。
class AdminBulkMail < ApplicationRecord
  NAME_PLACEHOLDER = "{{name}}".freeze
  DEFAULT_NAME = "メンバー".freeze
  SUBJECT_MAX_LENGTH = 200
  BODY_MAX_LENGTH = 10_000

  belongs_to :admin, optional: true
  has_many :recipients, class_name: "AdminBulkMailRecipient", dependent: :delete_all

  validates :subject, presence: true, length: { maximum: SUBJECT_MAX_LENGTH }
  validates :body, presence: true, length: { maximum: BODY_MAX_LENGTH }
  validates :request_token, presence: true

  # {{name}} を受信者の表示名に置き換える。表示名が空なら「メンバー」。
  def self.personalize(text, customer)
    name = customer&.name.to_s.strip.presence || DEFAULT_NAME
    text.to_s.gsub(NAME_PLACEHOLDER) { name }
  end

  # 状態ごとの件数。sending のうち DELIVERY_UNKNOWN_AFTER を過ぎたものは "unknown"(結果不明)として別に数える。
  def status_counts(now: Time.current)
    @status_counts ||= begin
      counts = recipients.group(:status).count
      result = AdminBulkMailRecipient.statuses.keys.index_with { |status| counts[status].to_i }
      unknown = recipients.sending.where("updated_at <= ?", now - AdminBulkMailRecipient::DELIVERY_UNKNOWN_AFTER).count
      result["sending"] -= unknown
      result.merge("unknown" => unknown)
    end
  end
end
