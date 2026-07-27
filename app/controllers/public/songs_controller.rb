class Public::SongsController < ApplicationController
  before_action :authenticate_customer!

  def show
    @event = Event.find(params[:event_id])
    @song = @event.songs.find(params[:id])
    @can_save_as_template = current_customer.can_edit_event?(@event) && @song.song_name.present?
  end

end
