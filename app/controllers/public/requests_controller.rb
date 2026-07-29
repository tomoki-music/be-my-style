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

  # 通常通知(request-msg)の対象は従来通り「イベント開催者+イベント参加者」のまま維持する。
  # メンション通知(mention_request)の対象は「イベント開催元コミュニティの有効メンバー」
  # (Requests::MentionResolver、演奏参加の有無を問わない)であり、通常通知の対象と重なるとは
  # 限らない(例: コミュニティメンバーだが未参加の人がメンションされた場合等)。
  # そのため両者は独立に算出し、メンションされた相手には通常通知を送らないことでのみ
  # 重複を防ぐ(投稿者本人はMentionResolver・通常対象のいずれからも除外済み)。
  def notify_request_recipients(event, request, poster)
    mentioned_customers = Requests::MentionResolver.call(
      request_text: request.request, event: event, poster: poster
    )
    mentioned_customer_ids = mentioned_customers.map(&:id)

    normal_recipients = ([event.customer] + event.participating_customers.where(is_deleted: false).to_a)
      .uniq(&:id)
      .reject { |customer| customer.id == poster.id }

    normal_recipients.each do |recipient|
      next if mentioned_customer_ids.include?(recipient.id)

      recipient.create_notification_request_msg(poster, event.id)
      if recipient.confirm_mail
        CustomerMailer.with(ac_customer: poster, ps_customer: recipient, event_id: event.id, request: request).request_msg_mail.deliver_later
      end
    end

    mentioned_customers.each do |mentioned_customer|
      mentioned_customer.create_notification_mention_request(poster, event.id)
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
