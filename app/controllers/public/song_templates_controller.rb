class Public::SongTemplatesController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_community

  def create
    song = Song.joins(:event).where(events: { community_id: @community.id }).find(params[:song_id])

    unless current_customer.can_edit_event?(song.event)
      return redirect_to public_event_song_path(song.event, song), alert: "テンプレートを作成する権限がありません。"
    end

    @community.song_templates.create!(
      customer: current_customer,
      source_song: song,
      song_name: song.song_name,
      artist_name: song.artist_name,
      youtube_url: song.youtube_url,
      introduction: song.introduction,
      chord_sheet_url: song.chord_sheet_url,
      tab_sheet_url: song.tab_sheet_url,
      musical_key: song.musical_key,
      capo: song.capo,
      chord_sheet_note: song.chord_sheet_note
    )

    redirect_to public_event_song_path(song.event, song), notice: "楽曲テンプレートを保存しました。"
  rescue ActiveRecord::RecordNotFound
    redirect_to public_events_path, alert: "対象の楽曲が見つかりませんでした。"
  end

  def destroy
    template = @community.song_templates.find(params[:id])

    unless template.customer_id == current_customer.id || current_customer.can_manage_community?(@community)
      return redirect_back fallback_location: public_community_path(@community), alert: "削除する権限がありません。"
    end

    template.destroy
    redirect_back fallback_location: public_community_path(@community), notice: "楽曲テンプレートを削除しました。"
  end

  private

  def set_community
    @community = Community.find_by!(id: params[:community_id], domain_id: @current_domain.id)
  end
end
