class Public::PerformanceRankingsController < ApplicationController
  # ログイン必須(氏名・プロフィール画像を表示するため。メンバー一覧と同じ扱い)。
  # /public 配下のため ApplicationController の authenticate_customer! と
  # ensure_music_domain_access_for_public_routes!(非 music ユーザーをリダイレクト)が効く。
  before_action :authenticate_customer!

  def index
    @ranking = PerformanceRankings::RankingQuery.new(
      kind: params[:kind],
      scope: params[:scope],
      community_id: params[:community_id],
      period: PerformanceRankings::Period.new(
        preset: params[:period],
        start_on: params[:start_on],
        end_on: params[:end_on]
      ),
      page: params[:page]
    )
    @rows = @ranking.rows
  end
end
