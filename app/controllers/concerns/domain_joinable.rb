module DomainJoinable
  extend ActiveSupport::Concern

  included do
    include DomainScopedAuth
    skip_before_action :authenticate_customer!
    before_action :authenticate_customer_for_domain_join!
    before_action :redirect_if_domain_already_enabled!, only: :show
  end

  def show
  end

  def create
    domain = Domain.find_by!(name: auth_domain_name)
    CustomerDomain.find_or_create_by!(customer: current_customer, domain: domain)
    redirect_to auth_root_path, notice: domain_auth_config[:join_notice]
  end

  private

  def authenticate_customer_for_domain_join!
    return if customer_signed_in?

    redirect_to auth_sign_in_path
  end

  def redirect_if_domain_already_enabled!
    return unless domain_member?(current_customer)

    redirect_to auth_root_path
  end
end
