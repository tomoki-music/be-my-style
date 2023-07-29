class ContactMailer < ApplicationMailer

  def send_mail(mail_title, mail_content, community_customers)
    @mail_title = mail_title
    @mail_content = mail_content
    mail bcc: community_customers.pluck(:email), subject: mail_title
    end
end
