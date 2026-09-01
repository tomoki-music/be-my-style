# ご意見・ご相談BOX に新規投稿があった際、全管理者へメール通知する。
# AdminSubscriptionNotifier と異なり AdminNotification レコードは作らない
# （AdminNotification は plan presence 必須＝サブスク専用のため）。メール通知のみ。
class AdminCustomerFeedbackNotifier
  def self.call(feedback)
    new(feedback).call
  end

  def initialize(feedback)
    @feedback = feedback
  end

  def call
    return unless @feedback&.persisted?

    Admin.find_each do |admin|
      AdminNotificationMailer.with(
        admin: admin,
        feedback: @feedback
      ).customer_feedback_created.deliver_later
    end
  end
end
