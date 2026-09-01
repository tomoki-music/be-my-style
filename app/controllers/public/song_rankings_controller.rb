class Public::SongRankingsController < ApplicationController
  # ログイン不要の公開ページ。集計データ(曲名・アーティスト名・成立回数)に個人情報は含まれず、
  # 非公開/下書き/キャンセル相当の状態を持つイベント・コミュニティも存在しないため公開して問題ない。
  # ルートを /public 配下に置かないことで ApplicationController の
  # ensure_music_domain_access_for_public_routes!(非musicユーザーをリダイレクト)の対象外にする。
  skip_before_action :authenticate_customer!, only: [:index]

  def index
    @ranking = SongRankings::RankingQuery.new(
      period: params[:period],
      year: params[:year],
      month: params[:month],
      community_id: params[:community_id],
      artist_name: params[:artist_name],
      page: params[:page]
    )
    @rows = @ranking.rows
  end
end
