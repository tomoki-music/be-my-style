class Public::RequestsController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:destroy]

  def create
    @event = Event.find(params[:event_id])
    @request = Request.new(request_params)
    @request.customer_id = current_customer.id
    @request.event_id = @event.id
    if @request.save!
      #イベント企画者への通知
      if current_customer != @event.customer
        @event.customer.create_notification_request_msg(current_customer, @event.id)
      end
      #イベント参加者への通知
      @event.songs.each do |song|
        song.join_parts.each do |join_part|
          join_part.customers.each do |customer|
            if current_customer != customer
              customer.create_notification_request_msg(current_customer, @event.id)
            end
          end
        end
      end

      flash.now[:notice] = 'リクエストを投稿しました'
    else
      redirect_back(fallback_location: root_path)
    end
  end

  def destroy
    @request = Request.find_by(id: params[:id], event_id: params[:event_id])
    if @request.destroy
      @event = Event.find(params[:event_id])
      flash.now[:alert] = 'リクエストを削除しました'
    else
      redirect_back(fallback_location: root_path)
    end
  end

  private

  def request_params
    params.require(:request).permit(:request)
  end

  def ensure_correct_customer
    request = Request.find_by(id: params[:id], event_id: params[:event_id])
    customer = request.customer
    unless customer == current_customer
      flash[:alert] = "リクエスト投稿者のみ削除できます"
      redirect_back(fallback_location: root_path)
    end
  end
end
