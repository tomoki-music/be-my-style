class AdminBulkMailDeliveryJob < ApplicationJob
  queue_as :default

  # 一括メールの宛先1人分を送る。行を pending → sending に切り替えられたときだけ送るので、
  # 同じ行のジョブが二重に入ったり再試行されたりしても、同じ人へ2通送らない。
  # 送信の途中で止まった行は sending のまま残し、自動では再送しない(画面では一定時間後に「結果不明」と出す)。
  # ログには会員 ID・行 ID だけを出す(メールアドレス・件名・本文は出さない)。
  def perform(recipient_id)
    recipient = AdminBulkMailRecipient.find_by(id: recipient_id)
    return if recipient.nil?
    return unless recipient.claim!

    customer = Customer.find_by(id: recipient.customer_id)
    reason = AdminBulkMails::RecipientResolver.exclusion_reason_for(customer)
    if reason
      recipient.update!(status: :skipped, failure_reason: AdminBulkMails::RecipientResolver::EXCLUSION_REASONS[reason])
      return
    end

    # 確定してからジョブが動くまでにアドレスが変わっていたら、確認画面に出ていないアドレスへは送らない。
    unless recipient.email_matches?(customer.email)
      recipient.update!(status: :skipped, failure_reason: AdminBulkMailRecipient::EMAIL_CHANGED_REASON)
      return
    end

    delivered = false
    # Action Mailer は debug レベルで宛先・件名・本文を含むメール全体をログに出すため、info 以上に絞る。
    ActionMailer::Base.logger.silence(::Logger::INFO) do
      AdminBulkMailer.member_mail(recipient).deliver_now
    end
    delivered = true
    recipient.update!(status: :sent, sent_at: Time.current)
  rescue => e
    Rails.logger.error("[AdminBulkMailDeliveryJob] recipient_id=#{recipient_id} delivered=#{delivered.inspect} #{e.class}")
    # 送信後の記録に失敗したときは「失敗」と書かない(届いている可能性がある)。sending のまま残し、結果不明として見せる。
    unless delivered
      recipient&.update_columns(status: AdminBulkMailRecipient.statuses[:failed], failure_reason: e.class.name.truncate(250), updated_at: Time.current)
    end
    # 再試行で同じ人へ重複して送らないよう re-raise しない。
  end
end
