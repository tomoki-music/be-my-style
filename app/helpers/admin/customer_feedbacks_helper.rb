module Admin::CustomerFeedbacksHelper
  # 未確認のご意見・ご相談件数。管理メニュー(PC/スマホ)と一覧画面ヘッダの複数箇所で
  # 参照するため、1リクエスト内で一度だけ COUNT してメモ化する。
  def admin_unread_customer_feedback_count
    return 0 unless admin_signed_in?

    @admin_unread_customer_feedback_count ||= CustomerFeedback.unread.count
  end
end
