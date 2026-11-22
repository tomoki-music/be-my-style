# Business スレッド投稿の通知メール(Business::ProjectThreads::NotifyPost が作った通知1件につき1通)。
# 後から送るため、引数は通知 ID だけにして送信時に読み直す。通知は投稿・スレッド・プロジェクト・宛先・投稿者の
# 削除と一緒に消えるので、見つからなければ送らない(例外にしない)。宛先の参加資格・メール受信設定も送信時に確かめ直す。
class BusinessProjectChatMailer < ApplicationMailer
  # 表示名だけビジネス用にする。送信元アドレスと経路は従来どおり（SenderConfig の切り替え対象外）。
  default from: MailFrom.business

  def thread_post_mail
    notification = Notification.unscoped.find_by(id: params[:notification_id], action: "project_message")
    @project_chat = notification&.project_chat
    @project_thread = @project_chat&.project_thread
    @project = @project_chat&.project
    @recipient = notification&.visited
    @poster = notification&.visitor
    return if [@project_chat, @project_thread, @project, @recipient, @poster].any?(&:nil?)

    require_notifiable_customer(@recipient)
    return unless @recipient.business_email_notifications_enabled? && @recipient.business_project_notification_recipient?(@project)

    url_options = Rails.application.config.x.business_share_url_options
    @poster_name = @poster.is_deleted? ? ApplicationHelper::WITHDRAWN_CUSTOMER_LABEL : @poster.name
    @thread_url = business_project_thread_url(@project, @project_thread, anchor: "post-project_chat-#{@project_chat.id}", **url_options)
    @business_mypage = business_customer_url(@recipient, **url_options)
    mail to: @recipient.email, subject: '参加中のプロジェクトに新しいコメントが届きました！'
  end
end
