class Admin::EventsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_event, only: [:show, :edit, :update, :destroy]

  def index
    @events = Event.includes(:community, :customer).order(created_at: :desc)
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
    @event = Event.new
    build_default_song
  end

  def create
    @event = Event.new(event_params)

    if @event.save
      redirect_to admin_event_path(@event), notice: "イベントを登録しました。"
    else
      ensure_song_presence
      render :new
    end
  end

  def edit
    ensure_song_presence
  end

  def update
    if @event.update(event_params)
      redirect_to admin_event_path(@event), notice: "イベントを更新しました。"
    else
      ensure_song_presence
      render :edit
    end
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
      :event_entry_deadline,
      :request_deadline,
      :entrance_fee,
      :place,
      :introduction,
      :address,
      :latitude,
      :longitude,
      :event_image,
      :url,
      :url_comment,
      song_ids:[],
      part_ids:[],
      songs_attributes: [
        :id, :event_id, :song_name, :performance_time, :performance_start_time,
        :youtube_url, :introduction, :position, :_destroy,
        join_parts_attributes: [:id, :join_part_name, :_destroy]
      ],
    )
  end

  def set_event
    @event = Event.find(params[:id])
  end

  def build_default_song
    @song = @event.songs.build
    %w[Vocal Guitar Bass Drums Keyboard].each do |part_name|
      @song.join_parts.build(join_part_name: part_name)
    end
  end

  def ensure_song_presence
    return if @event.songs.present?

    build_default_song
  end

end
