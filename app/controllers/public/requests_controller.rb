class Public::RequestsController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:destroy]

  def create
    @event = Event.find(params[:event_id])
    @request = Request.new(request_params)
    @request.customer_id = current_customer.id
    @request.event_id = @event.id
    if @request.save
      notify_request_recipients(@event, @request, current_customer)
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

  # イベント開催者+現在の参加者(投稿者本人を除く)へ通知する。
  # 本文でメンションされた相手にはmention_request通知のみを送り、通常のrequest-msg通知は
  # 重複作成しない(同一投稿・同一相手への二重通知防止)。@ALLと個別メンションが両方
  # 含まれていてもRequests::MentionResolverが重複排除済みの配列を返すため、通知は1人1件になる。
  def notify_request_recipients(event, request, poster)
    mentioned_customer_ids = Requests::MentionResolver.call(
      request_text: request.request, event: event, poster: poster
    ).map(&:id)

    recipients = ([event.customer] + event.participating_customers.where(is_deleted: false).to_a)
      .uniq(&:id)
      .reject { |customer| customer.id == poster.id }

    recipients.each do |recipient|
      if mentioned_customer_ids.include?(recipient.id)
        recipient.create_notification_mention_request(poster, event.id)
      else
        recipient.create_notification_request_msg(poster, event.id)
        if recipient.confirm_mail
          CustomerMailer.with(ac_customer: poster, ps_customer: recipient, event_id: event.id, request: request).request_msg_mail.deliver_later
        end
      end
    end
  end

  def request_params
    params.require(:request).permit(:request, :stamp_type)
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
