class ApplicationMailer < ActionMailer::Base
  default from: '管理人より<from@example.com>'
  layout 'mailer'

  after_action :cancel_delivery_unless_customers_notifiable

  private

  # このメールを送るために「退会していない」必要がある会員(宛先の会員、学習の先生など)を登録する。
  # 判定はメール本文を作った直後(= 実際の配信の直前)に DB から読み直して行う。deliver_later で
  # 退会前に予約されたメールや、失敗後に再実行されたメールも、その時点で退会済みなら送らない。
  # 1通 = 1宛先のメール用。複数の宛先をまとめるメールは、宛先を選ぶときに Customer.notifiable で絞る。
  def require_notifiable_customer(customer)
    (@required_notifiable_customer_ids ||= []) << customer&.id
  end

  def cancel_delivery_unless_customers_notifiable
    ids = @required_notifiable_customer_ids
    return if ids.blank?

    unique_ids = ids.uniq
    return if unique_ids.none?(&:nil?) && Customer.notifiable.where(id: unique_ids).count == unique_ids.size

    message.perform_deliveries = false
    # 宛先アドレスは個人情報のためログに出さない(会員 ID のみ)。
    Rails.logger.info(
      "[MailDelivery] 退会済み・存在しない会員宛てのため送信しません " \
      "mailer=#{self.class.name} action=#{action_name} customer_ids=#{unique_ids.compact.join(',')}"
    )
  end
end
