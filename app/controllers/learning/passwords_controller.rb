class Learning::PasswordsController < Public::PasswordsController
  include DomainScopedPassword

  domain_auth_for :learning
end
