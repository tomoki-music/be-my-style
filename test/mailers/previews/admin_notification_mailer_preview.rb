# Preview all emails at http://localhost:3000/rails/mailers/admin_notification_mailer
class AdminNotificationMailerPreview < ActionMailer::Preview
  # http://localhost:3000/rails/mailers/admin_notification_mailer/customer_feedback_created
  #
  # プレビューは描画のみ（enqueue・実送信なし）。DB へレコードを作らず、
  # 実在ユーザーの情報も参照しないよう、すべてインメモリのダミーで構築する。
  def customer_feedback_created
    AdminNotificationMailer.with(admin: preview_admin, feedback: preview_feedback)
                           .customer_feedback_created
  end

  private

  def preview_admin
    Admin.new(id: 0, name: "運営管理者", email: "admin@example.test")
  end

  def preview_feedback
    customer = Customer.new(id: 0, name: "サンプル利用者", email: "sample-user@example.test")

    CustomerFeedback.new(
      id: 999_999,
      customer: customer,
      category: :bug_report,
      subject: "検索結果が表示されないことがある",
      body: "イベント検索でジャンルを指定すると結果が0件になります。\n\n再現手順:\n1. 検索画面を開く\n2. ジャンルを絞り込む\n3. 検索する",
      created_at: Time.current
    )
  end
end
