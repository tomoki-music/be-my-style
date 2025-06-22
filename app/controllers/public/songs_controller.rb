class Public::SongsController < ApplicationController
  before_action :authenticate_customer!

  def show
    @event = Event.find(params[:event_id])
    @song = @event.songs.find(params[:id])
  end

end
