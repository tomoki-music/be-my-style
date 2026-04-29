class Learning::JoinsController < ApplicationController
  include DomainJoinable

  domain_auth_for :learning
end
