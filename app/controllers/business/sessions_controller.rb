class Business::SessionsController < Public::SessionsController
  include DomainScopedSession

  domain_auth_for :business
end
