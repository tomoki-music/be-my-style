class Singing::RegistrationsController < Public::RegistrationsController
  include DomainScopedRegistration

  domain_auth_for :singing
end
