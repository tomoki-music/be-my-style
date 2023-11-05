class Public::EventsController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_event, only: [:show, :edit, :update, :destroy]
  before_action :ensure_correct_customer, only: [:update, :edit, :destroy]

  def index
    @events = Event.all.order(created_at: :desc).page(params[:page]).per(5)
  end

  def show
    @owner = Customer.find(@event.customer.id)
    @community = Community.find(@event.community_id)
    @latitude = @event.latitude
    @longitude = @event.longitude
    @address = @event.address

    joined_member_ids = []
    @event.songs.each do |song|
      joined_member_ids += song.customers.distinct.pluck(:id)
    end
    @joined_member_counts = joined_member_ids.uniq.length

    @vocal = []
    @guitar = []
    @bass = []
    @keyboard = []
    @drums = []
    @others = []
  end

  def new
    @event = Event.new
    @song = @event.songs.build
    @community_id = params[:community_id]
  end

  def create
    @event = Event.new(event_params)
    @event.customer_id = current_customer.id
    @event.community_id = params[:event][:community_id].to_i
    if @event.save
      if current_customer.chat_room_customers.present?
        community_ids = current_customer.chat_room_customers.pluck(:community_id)
        community_ids.each do |community_id|
          Community.where(id: community_id).each do |community|
            community.customers.each do |customer|
              if customer.id != current_customer.id
                customer.create_notification_event_for_community(current_customer, @event.id, community.id)
              end
            end
          end
        end
      elsif current_customer.followers.present?
        current_customer.followers.each do |customer|
          customer.create_notification_event_for_follow(current_customer, @event.id)
        end
      end
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
    event = Event.find(params[:event_id])
    community = Community.find(event.community_id)
    customer_ids = community.customers.pluck(:id)
    if customer_ids.include?(current_customer.id)
      if params[:event][:song_ids] == [""] 
        redirect_to public_event_path(event), alert: "参加する曲にチェックを入れて下さい。"
      else
        song_ids = params[:event][:song_ids].reject {|i| i == "" }
        customer = current_customer
        song_ids.each do |song_id|
          Song.find(song_id).customers << customer
        end
        event.customer.create_notification_join_event(current_customer, event.id)
        redirect_to public_event_path(event), notice: "イベントへの参加が完了しました!"
      end
    else
      redirect_to public_community_path(community), alert: "まずこちらのコミュニティに参加してください"
    end
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

  def ensure_correct_customer
    @event = Event.find(params[:id])
    unless @event.customer == current_customer
      redirect_to public_events_path, alert: "編集権限がありません。"
    end
  end

end
