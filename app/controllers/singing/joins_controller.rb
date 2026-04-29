class Singing::JoinsController < ApplicationController
  include DomainJoinable

  domain_auth_for :singing
end
