class Business::RegistrationsController < Public::RegistrationsController
  include DomainScopedRegistration

  domain_auth_for :business
end
