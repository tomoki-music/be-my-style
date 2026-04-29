module DomainScopedRegistration
  extend ActiveSupport::Concern

  included do
    include DomainScopedAuth
  end

  def new
    super
    resource.domain_name = auth_domain_name
  end

  protected

  def after_sign_up_path_for(resource)
    super(resource)
  end

  def after_inactive_sign_up_path_for(_resource)
    auth_sign_in_path
  end

  private

  def normalized_requested_domain_name
    auth_domain_name
  end
end
