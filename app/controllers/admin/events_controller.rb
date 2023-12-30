class Admin::EventsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_event, only: [:show, :edit, :update, :destroy]

  def index
    @events = Event.all.order(created_at: :desc)
  end

  def show
    joined_member_ids = []
    @event.songs.each do |song|
      song.join_parts.each do |join_part|
        joined_member_ids += join_part.customers.pluck(:id)
      end
    end
    @joined_member_counts = joined_member_ids.uniq.length
  end

  def new

  end

  def create

  end

  def edit

  end

  def update

  end

  def destroy
    @event.songs.destroy_all
    @event.destroy
    redirect_to admin_events_path, alert: "イベントを削除しました!"
  end

  def delete
    event = Event.find(params[:event_id])
    join_part = JoinPart.find(params[:join_part_id])
    customer = Customer.find(params[:customer_id])
    join_part.customers.delete(customer)
    redirect_to admin_event_path(event), alert: "選択したユーザーを削除しました!"
  end

  private

  def event_params
    params.require(:event).permit(
      :customer_id,
      :community_id,
      :event_name,
      :event_start_time,
      :event_end_time,
      :entrance_fee,
      :place,
      :introduction,
      :address,
      :latitude,
      :longitude,
      :event_image,
      song_ids:[],
      part_ids:[],
      songs_attributes: [:id, :song_name, :youtube_url, :introduction, :_destroy],
    )
  end

  def set_event
    @event = Event.find(params[:id])
  end

end
