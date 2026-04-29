class Learning::SessionsController < Public::SessionsController
  include DomainScopedSession

  domain_auth_for :learning
end
