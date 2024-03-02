class Public::RequestsController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:destroy]

  def create
    @event = Event.find(params[:event_id])
    @request = Request.new(request_params)
    @request.customer_id = current_customer.id
    @request.event_id = @event.id
    if @request.save
      #イベント開催者への通知
      if current_customer != @event.customer
        @event.customer.create_notification_request_msg(current_customer, @event.id)
        if @event.customer.confirm_mail
          CustomerMailer.with(ac_customer: current_customer, ps_customer: @event.customer, event_id: @event.id, request: @request).request_msg_mail.deliver_later
        end
      end
      #イベント参加者への通知
      customer_ids = []
      @event.songs.each do |song|
        song.join_parts.each do |join_part|
          customer_ids += join_part.customers.pluck(:id)
        end
      end
      customer_ids.uniq.each do |customer_id|
        if current_customer != Customer.find(customer_id) && @event.customer != Customer.find(customer_id)
          Customer.find(customer_id).create_notification_request_msg(current_customer, @event.id)
          if Customer.find(customer_id).confirm_mail
            CustomerMailer.with(ac_customer: current_customer, ps_customer: Customer.find(customer_id), event_id: @event.id, request: @request).request_msg_mail.deliver_later
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
