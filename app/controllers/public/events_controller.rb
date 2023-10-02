class Public::EventsController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_event, only: [:show, :edit, :update, :destroy, :join]
  before_action :ensure_correct_customer, only: [:update, :edit, :destroy]

  def index
    @events = Event.all.order(created_at: :desc).page(params[:page]).per(10)
  end

  def show
    @owner = Customer.find(@event.customer.id)
    @community = Community.find(@event.community_id)
    @latitude = @event.latitude
    @longitude = @event.longitude
    @address = @event.address
  end

  def new
    @event = Event.new
    @song = @event.songs.build
  end

  def create
    @event = Event.new(event_params)
    @event.customer_id = current_customer.id
    @event.community_id = params[:event][:community_id].to_i
    if @event.save!
      redirect_to public_event_path(@event), notice: "イベントを投稿しました！"
    else
      render :new, alert: "登録できませんでした。お手数ですが、入力内容をご確認のうえ再度お試しください"
    end
  end

  def edit
    @latitude = @event.latitude
    @longitude = @event.longitude
    @address = @event.address
  end

  def update
    if @event.update(event_params)
      redirect_to public_event_path(@event), notice: "イベントの編集が完了しました!"
    else
      render "edit", alert: "もう一度お試しください。"
    end
  end

  def destroy
    @event.songs.destroy_all
    @event.destroy
    redirect_to public_events_path, alert: "イベントを削除しました!"
  end

  def join
    
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
      songs_attributes: [:id, :song_name, :youtube_url, :introduction, :_destroy],
    )
  end

  def set_event
    @event = Event.find(params[:id])
  end

  def ensure_correct_customer
    @event = Event.find(params[:id])
    unless @event.customer == current_customer
      redirect_to public_events_path, alert: "編集権限がありません。"
    end
  end

end
