class Learning::RegistrationsController < Public::RegistrationsController
  include DomainScopedRegistration

  domain_auth_for :learning
end
