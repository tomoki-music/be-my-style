class ApplicationMailer < ActionMailer::Base
  default from: '管理人より<from@example.com>'
  layout 'mailer'
end
