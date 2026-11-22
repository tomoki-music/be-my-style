# バンド出演枠への「このバンドを応援する📣」の登録・取消。曲への応援(SongCheersController)とは独立している。
class Public::EventBandCheersController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_event_and_band

  def create
    # 参加資格・受付条件は曲への応援と共通(Event#cheer_unavailable_reason)。
    if (reason = @event.cheer_unavailable_reason(current_customer))
      redirect_back_to_band alert: reason
      return
    end

    if EventBandCheer.exists?(event_band_id: @band.id, customer_id: current_customer.id)
      redirect_back_to_band notice: "「#{@band.name}」はすでに応援しています📣"
      return
    end

    begin
      EventBandCheer.create!(event_band: @band, customer: current_customer)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # 二重送信などで先に同じ応援が登録された場合も、目的の状態になっているので成功として扱う。
      nil
    end
    redirect_back_to_band notice: "「#{@band.name}」を応援しました📣"
  end

  def destroy
    EventBandCheer.where(event_band_id: @band.id, customer_id: current_customer.id).destroy_all
    redirect_back_to_band notice: "「#{@band.name}」の応援を取り消しました。"
  end

  private

  def set_event_and_band
    @event = Event.find(params[:event_id])
    @band = @event.event_bands.find(params[:band_id])
  end

  def redirect_back_to_band(flash_options)
    redirect_back(fallback_location: public_event_path(@event, anchor: "event-bands"), **flash_options)
  end
end
