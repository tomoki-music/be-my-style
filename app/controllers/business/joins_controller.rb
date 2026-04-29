class Business::JoinsController < ApplicationController
  include DomainJoinable

  domain_auth_for :business
end
