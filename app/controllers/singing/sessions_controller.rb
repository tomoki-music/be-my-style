class Singing::SessionsController < Public::SessionsController
  include DomainScopedSession

  domain_auth_for :singing
end
