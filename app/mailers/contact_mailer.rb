# 音楽のコミュニティ（Public::CommunitiesController）からのお知らせ。
class ContactMailer < ApplicationMailer
  default from: MailFrom.music

  def send_mail(mail_title, mail_content, community, community_customers)
    @mail_title = mail_title
    @mail_content = mail_content
    @community = community
    mail bcc: community_customers.pluck(:email), subject: mail_title
    end
end
