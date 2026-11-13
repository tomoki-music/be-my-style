# 音楽のコミュニティ（Public::CommunitiesController）からのお知らせ。
class ContactMailer < ApplicationMailer
  default from: MailFrom.music

  def send_mail(mail_title, mail_content, community, community_customers)
    @mail_title = mail_title
    @mail_content = mail_content
    @community = community
    # 複数宛先のため、退会者だけを宛先から外してほかのメンバーへは送る。
    recipients = community_customers.merge(Customer.notifiable).pluck(:email)
    mail bcc: recipients, subject: mail_title
    message.perform_deliveries = false if recipients.empty?
  end
end
