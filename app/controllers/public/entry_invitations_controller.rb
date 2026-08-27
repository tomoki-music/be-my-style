class Public::EntryInvitationsController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_event
  before_action :authorize_sender!
  before_action :set_song_and_join_part

  # 確認画面。選択された customer_id 群は信用せず、サーバー側で
  # 「このイベント・この曲・このパートの演奏経験者」に絞り直したうえで表示する。
  def new
    @recipients = eligible_recipients(requested_customer_ids_from_query)

    if @recipients.empty?
      redirect_to public_event_path(@event), alert: "送信対象者が選択されていません。"
    end
  end

  # 実送信(非同期)。送信対象・権限は EntryInvitations::Sender が再計算する。
  def create
    result = EntryInvitations::Sender.call(
      event: @event,
      song: @song,
      join_part: @join_part,
      sender: current_customer,
      requested_customer_ids: create_params[:customer_ids]
    )

    unless result.success?
      redirect_to public_event_path(@event), alert: result.error
      return
    end

    redirect_to public_event_path(@event), flash: flash_for(result)
  end

  private

  def set_event
    @event = Event.includes(songs: [:song_master, { join_parts: :customers }]).find(params[:event_id])
  end

  def authorize_sender!
    return if current_customer.can_destroy_event?(@event)

    redirect_to public_event_path(@event), alert: "この操作を行う権限がありません。"
  end

  def set_song_and_join_part
    song_id = params[:song_id].presence || create_params[:song_id]
    join_part_id = params[:join_part_id].presence || create_params[:join_part_id]

    @song = @event.songs.find_by(id: song_id)
    @join_part = @song&.join_parts&.find_by(id: join_part_id)

    return if @song && @join_part

    redirect_to public_event_path(@event), alert: "曲またはパートの指定が正しくありません。"
  end

  def create_params
    params.fetch(:entry_invitation, {}).permit(:song_id, :join_part_id, customer_ids: [])
  end

  # "12" のような正の整数文字列のみ許可する(Public::EventsController#normalize_join_part_ids と同じ考え方)。
  def requested_customer_ids_from_query
    Array(params[:customer_ids]).map { |id| id.to_s.strip }.select { |id| id.match?(/\A\d+\z/) }.map(&:to_i).uniq
  end

  # 確認画面表示用。Sender と同じ経験者集合で交差を取る(表示と実送信のズレ防止)。
  def eligible_recipients(customer_ids)
    key = PerformanceHistory::ExperiencedCustomersQuery.key_for(@song.song_master_id, @join_part.join_part_name)
    return [] if key.nil?

    experienced = PerformanceHistory::ExperiencedCustomersQuery.call(@event).fetch(key, [])
    experienced_by_id = experienced.index_by(&:id)
    customer_ids.filter_map { |id| experienced_by_id[id] }
  end

  def flash_for(result)
    payload = {}
    payload[:notice] = "#{result.queued_count}人へエントリー依頼を送信しました。" if result.queued_count.positive?

    if result.skipped.any?
      counts = result.skipped.group_by { |s| s[:reason] }.transform_values(&:size)
      details = counts.map { |reason, count| "#{EntryInvitations::Sender::SKIP_REASON_LABELS.fetch(reason, reason)}: #{count}人" }
      payload[:alert] = "送信しなかった人がいます（#{details.join(' / ')}）。"
    end

    payload[:alert] ||= "送信対象者がいませんでした。" if result.queued_count.zero?
    payload
  end
end
