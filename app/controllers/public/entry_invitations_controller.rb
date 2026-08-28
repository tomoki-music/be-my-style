class Public::EntryInvitationsController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_event
  before_action :authorize_sender!

  # 確認画面。パネルから GET で渡される targets[] は信用せず、TargetResolver で
  # 「このイベント・募集中の曲/パート・その演奏経験者」だけに絞り直して表示する。
  # hidden field へ持ち越すのも検証済みトークンのみ。
  def new
    parsed_count = EntryInvitations::TargetParser.parse(params[:targets]).size

    if parsed_count > EntryInvitations::TargetParser::MAX_TARGETS
      redirect_to public_event_path(@event),
        alert: "一度に選択できるのは#{EntryInvitations::TargetParser::MAX_TARGETS}人までです。数を減らして選び直してください。"
      return
    end

    @groups = EntryInvitations::TargetResolver.call(event: @event, raw_targets: params[:targets])
    @recipient_count = @groups.sum { |group| group.customers.size }

    return unless @groups.empty?

    redirect_to public_event_path(@event), alert: "送信対象者が選択されていません。"
  end

  # 実送信(非同期)。確認画面の hidden field も信用せず、BatchSender / Sender が
  # 曲・パート・経験者・権限・再送間隔をサーバー側で再計算する。
  def create
    result = EntryInvitations::BatchSender.call(
      event: @event,
      sender: current_customer,
      raw_targets: params[:targets]
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

  # 過度に技術的でない日本語で「送信できた数 / 送信済みでスキップ / 対象外でスキップ」をまとめる。
  def flash_for(result)
    segments = []
    segments << "#{result.queued_count}件のエントリー依頼を送信しました。" if result.queued_count.positive?
    segments << "#{result.recently_sent_count}件は送信済みのためスキップしました。" if result.recently_sent_count.positive?
    segments << "#{result.skipped_count}件は対象外のためスキップしました。" if result.skipped_count.positive?

    if result.queued?
      { notice: segments.join(" ") }
    else
      { alert: segments.presence&.join(" ") || "送信できる対象者がいませんでした。" }
    end
  end
end
