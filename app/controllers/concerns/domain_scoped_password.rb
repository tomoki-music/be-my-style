module DomainScopedPassword
  extend ActiveSupport::Concern

  included do
    include DomainScopedAuth
  end

  def after_resetting_password_path_for(_resource)
    auth_root_path
  end

  def after_sending_reset_password_instructions_path_for(_resource_name)
    auth_sign_in_path
  end
end
