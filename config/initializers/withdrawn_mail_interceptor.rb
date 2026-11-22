require Rails.root.join("lib/withdrawn_mail_interceptor").to_s

ActiveSupport.on_load(:action_mailer) do
  ActionMailer::Base.register_interceptor(WithdrawnMailInterceptor)
end
