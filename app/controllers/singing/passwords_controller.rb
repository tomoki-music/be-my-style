class Singing::PasswordsController < Public::PasswordsController
  include DomainScopedPassword

  domain_auth_for :singing
end
