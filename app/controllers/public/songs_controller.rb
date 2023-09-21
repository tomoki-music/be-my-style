class Public::SongsController < ApplicationController
  before_action :authenticate_customer!
end
