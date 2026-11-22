# イベントのバンド出演枠(バンド名・パートごとの固定担当者・出演曲)の管理。
# 変更できるのはイベントの編集権限を持つ人だけ(Public::EventsController#edit と同じ Customer#can_edit_event?)。
class Public::EventBandsController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_event
  before_action :authorize_event_edit!
  before_action :set_band, only: [:edit, :update, :destroy]
  before_action :set_form_options, only: [:new, :create, :edit, :update]

  def index
    @bands = @event.event_bands.includes({ members: :customer }, :songs)
  end

  def new
    @band = @event.event_bands.build
  end

  def create
    @band = @event.event_bands.build
    assign_band_attributes
    if @band.save
      redirect_to public_event_bands_path(@event), notice: "バンド出演枠「#{@band.name}」を登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    assign_band_attributes
    if @band.save
      redirect_to public_event_bands_path(@event), notice: "バンド出演枠「#{@band.name}」を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # 出演曲は削除せず、通常のセッション曲(一般募集)に戻す(EventBand has_many :songs, dependent: :nullify)。
  def destroy
    @band.destroy
    redirect_to public_event_bands_path(@event), notice: "バンド出演枠「#{@band.name}」を削除しました。出演曲は通常のセッション曲に戻りました。"
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def authorize_event_edit!
    return if current_customer.can_edit_event?(@event)

    redirect_to public_event_path(@event), alert: "このイベントのバンド出演枠を変更する権限がありません。"
  end

  def set_band
    @band = @event.event_bands.includes(:members, :songs).find(params[:id])
  end

  def set_form_options
    @member_candidates = @event.hosting_community_members.order(:name)
    @songs = @event.songs.includes(join_parts: :join_part_customers)
  end

  def assign_band_attributes
    @band.name = band_params[:name]
    @band.assign_part_members(band_params[:members])
    @band.selected_song_ids = band_params[:song_ids]
  end

  def band_params
    member_fields = JoinPart::NAME_OPTIONS.index_with { [:customer_id, :display_name] }
    params.require(:event_band).permit(:name, song_ids: [], members: member_fields)
  end
end
