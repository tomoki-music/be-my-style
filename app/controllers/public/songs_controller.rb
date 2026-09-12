class Public::SongsController < ApplicationController
  before_action :authenticate_customer!

  def show
    @event = Event.find(params[:event_id])
    # join_parts: :customersをpreloadし、参加状況表示(パートごとのエントリー済みメンバー)で
    # Public::EventsController#showと同じくN+1を発生させない。
    @song = @event.songs.includes(join_parts: :customers).find(params[:id])
    @can_save_as_template = current_customer.can_edit_event?(@event) && @song.song_name.present?

    # 「演奏経験のある人」表示は、楽曲一覧(Public::EventsController#show)と同じ
    # PerformanceHistory::ExperiencedCustomersQueryをそのまま再利用する
    # (募集中判定・経験者判定を画面ごとに新設しない)。
    @experienced_customers_by_song_part = PerformanceHistory::ExperiencedCustomersQuery.call(@event)

    # 開催コミュニティの所属者だけがエントリーできる、というjoinアクションの既存基準を
    # 表示制御にも再利用する(実際の登録可否はjoinアクション側が独立して再検証する)。
    @can_join_event = @event.community_member?(current_customer)
  end

end
