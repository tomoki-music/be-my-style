class AdminBulkMailer < ApplicationMailer
  default from: MailFrom.music

  # 管理画面から送る名前入りの一括メール。1通 = 1宛先(To に複数人を入れない・CC/BCC を使わない)。
  # 本文はプレーンテキストのみ。{{name}} は受信者の表示名(空なら「メンバー」)に置き換える。
  def member_mail(recipient)
    @customer = recipient.customer
    require_notifiable_customer(@customer)
    bulk_mail = recipient.admin_bulk_mail
    @body = AdminBulkMail.personalize(bulk_mail.body, @customer)

    mail(to: @customer&.email, subject: AdminBulkMail.personalize(bulk_mail.subject, @customer)) do |format|
      format.text
    end
  end
end
