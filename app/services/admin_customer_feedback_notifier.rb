# ご意見・ご相談BOX に新規投稿があった際、全管理者へメール通知する。
# AdminSubscriptionNotifier と異なり AdminNotification レコードは作らない
# （AdminNotification は plan presence 必須＝サブスク専用のため）。メール通知のみ。
#
# 安全設計:
# - development では既定でメールを送らない（実 Gmail SMTP へ接続してしまうため）。
#   ENABLE_CUSTOMER_FEEDBACK_EMAILS="true"（厳密一致）を設定したときだけ有効化する。
# - Admin ごとに enqueue 失敗を握らず「記録して継続」する（1 人の失敗で全体を止めない）。
# - .call は StandardError を外へ出さない。投稿保存の成否をメール通知失敗から分離する。
class AdminCustomerFeedbackNotifier
  ENABLE_ENV_KEY = "ENABLE_CUSTOMER_FEEDBACK_EMAILS".freeze
  LOG_TAG = "[AdminCustomerFeedbackNotifier]".freeze

  def self.call(feedback)
    new(feedback).call
  end

  def initialize(feedback)
    @feedback = feedback
  end

  def call
    return unless @feedback&.persisted?

    unless mails_enabled?
      # ログには feedback ID のみ。投稿本文・件名・投稿者名/メール・管理者メールは残さない。
      Rails.logger.info("#{LOG_TAG} メール送信が無効なためスキップ feedback_id=#{@feedback.id}")
      return
    end

    Admin.find_each { |admin| enqueue_for(admin) }
  rescue StandardError => e
    # 環境判定・Admin 取得など想定外の失敗でも呼び出し元（投稿処理）へ波及させない。
    Rails.logger.error("#{LOG_TAG} 通知処理で予期しないエラー feedback_id=#{@feedback&.id} error=#{e.class}: #{e.message}")
  end

  private

  def enqueue_for(admin)
    AdminNotificationMailer.with(
      admin: admin,
      feedback: @feedback
    ).customer_feedback_created.deliver_later
  rescue StandardError => e
    # 1 人分の enqueue 失敗で他の Admin への通知を止めない。ログは ID と例外情報のみ。
    Rails.logger.error("#{LOG_TAG} enqueue 失敗 feedback_id=#{@feedback.id} admin_id=#{admin.id} error=#{e.class}: #{e.message}")
  end

  # production / test では常に有効。development のみ ENV での明示有効化が必要。
  def mails_enabled?
    return true unless Rails.env.development?

    ENV[ENABLE_ENV_KEY] == "true"
  end
end
