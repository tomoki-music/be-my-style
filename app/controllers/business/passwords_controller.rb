class Business::PasswordsController < Public::PasswordsController
  include DomainScopedPassword

  domain_auth_for :business
end
