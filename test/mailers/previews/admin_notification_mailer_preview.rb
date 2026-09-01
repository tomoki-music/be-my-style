# Preview all emails at http://localhost:3000/rails/mailers/admin_notification_mailer
class AdminNotificationMailerPreview < ActionMailer::Preview
  # http://localhost:3000/rails/mailers/admin_notification_mailer/customer_feedback_created
  def customer_feedback_created
    admin = Admin.first || Admin.new(email: "admin@example.com", name: "管理者")
    feedback = CustomerFeedback.includes(:customer).recent.first || sample_feedback

    AdminNotificationMailer.with(admin: admin, feedback: feedback).customer_feedback_created
  end

  private

  # DB に投稿が無い環境向けのダミー（保存はしない）。
  def sample_feedback
    customer = Customer.first || Customer.new(name: "山田太郎", email: "taro@example.com")
    CustomerFeedback.new(
      customer: customer,
      category: :bug_report,
      subject: "検索結果が表示されないことがある",
      body: "イベント検索でジャンルを指定すると結果が0件になります。\n\n再現手順:\n1. 検索画面を開く\n2. ジャンルを「ロック」に設定\n3. 検索ボタンを押す"
    )
  end
end
