class AdminBulkMailRecipient < ApplicationRecord
  # pending: 受付済み・送信待ち
  # sending: ジョブが送信を始めた(この状態からは再送しない。途中で止まった場合も重複送信を避けて残し、
  #          DELIVERY_UNKNOWN_AFTER を過ぎたら「結果不明」として表示する)
  # sent: 送信成功
  # failed: 送信失敗(failure_reason に理由。メールアドレス・本文は入れない)
  # skipped: 送る直前の再確認で対象外になった、または非本番環境のため送信しなかった
  enum status: { pending: 0, sending: 1, sent: 2, failed: 3, skipped: 4 }

  # 送信を始めてからこの時間を過ぎても sending のままなら、処理が途中で止まったとみなす。
  # 届いたかどうか分からないため、自動では再送しない。
  DELIVERY_UNKNOWN_AFTER = 10.minutes
  DELIVERY_UNKNOWN_LABEL = "結果不明（送信中のまま止まりました。自動では再送しません）".freeze
  EMAIL_CHANGED_REASON = "確認後にメールアドレスが変わったため送信しませんでした".freeze
  EMAIL_DIGEST_PURPOSE = "admin_bulk_mail_recipient/email_digest".freeze

  STATUS_LABELS = {
    "pending" => "送信待ち",
    "sending" => "送信中",
    "sent" => "送信成功",
    "failed" => "失敗",
    "skipped" => "送信しなかった"
  }.freeze

  belongs_to :admin_bulk_mail
  belongs_to :customer, optional: true

  # 確認画面に出したアドレスの照合用の値。アドレスそのものは保存しない。
  def self.email_digest_for(email)
    key = Rails.application.key_generator.generate_key(EMAIL_DIGEST_PURPOSE, 32)
    OpenSSL::HMAC.hexdigest("SHA256", key, email.to_s.strip.downcase)
  end

  def email_matches?(email)
    email_digest.present? && ActiveSupport::SecurityUtils.secure_compare(email_digest, self.class.email_digest_for(email))
  end

  def delivery_unknown?(now: Time.current)
    sending? && updated_at <= now - DELIVERY_UNKNOWN_AFTER
  end

  def status_label(now: Time.current)
    return DELIVERY_UNKNOWN_LABEL if delivery_unknown?(now: now)

    STATUS_LABELS.fetch(status, status)
  end

  # pending の行だけを sending にする。ほかのジョブ(二重投入・再試行)が先に取っていたら false。
  def claim!
    self.class.where(id: id, status: self.class.statuses[:pending])
        .update_all(status: self.class.statuses[:sending], updated_at: Time.current) == 1
  end
end
