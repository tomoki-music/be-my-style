# 楽曲の「応援する📣」の登録・取消。演奏エントリー(JoinPartCustomer)には触れないので、
# 応援を取り消しても同じ曲のエントリーはそのまま残る。
class Public::SongCheersController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_event_and_song

  def create
    # 参加資格・受付条件はバンドへの応援と共通(Event#cheer_unavailable_reason)。
    if (reason = @event.cheer_unavailable_reason(current_customer))
      redirect_back_to_song alert: reason
      return
    end

    if SongCheer.exists?(song_id: @song.id, customer_id: current_customer.id)
      redirect_back_to_song notice: "「#{@song.song_name}」はすでに応援しています📣"
      return
    end

    begin
      SongCheer.create!(song: @song, customer: current_customer)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # 二重送信などで先に同じ応援が登録された場合も、目的の状態になっているので成功として扱う。
      nil
    end
    redirect_back_to_song notice: "「#{@song.song_name}」を応援しました📣"
  end

  def destroy
    SongCheer.where(song_id: @song.id, customer_id: current_customer.id).destroy_all
    redirect_back_to_song notice: "「#{@song.song_name}」の応援を取り消しました。"
  end

  private

  def set_event_and_song
    @event = Event.find(params[:event_id])
    @song = @event.songs.find(params[:song_id])
  end

  def redirect_back_to_song(flash_options)
    redirect_back(fallback_location: public_event_path(@event, anchor: "event-songs"), **flash_options)
  end
end
