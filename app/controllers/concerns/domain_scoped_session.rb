module DomainScopedSession
  extend ActiveSupport::Concern

  included do
    include DomainScopedAuth
  end

  def after_sign_in_path_for(resource)
    session[:customer_sign_out_redirect_to] = auth_sign_in_path
    return super if domain_member?(resource)

    auth_join_path
  end

  def after_sign_out_path_for(_resource)
    auth_sign_in_path
  end
end
