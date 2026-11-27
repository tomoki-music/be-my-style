# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  # 管理画面の一括メール(Admin::BulkMailsController)の件名・本文。会員へ送る文面をログに残さない。
  "bulk_mail.subject", "bulk_mail.body"
]
