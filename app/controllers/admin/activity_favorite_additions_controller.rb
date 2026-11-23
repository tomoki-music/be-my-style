# 管理画面の活動報告一覧から、運営所有アカウントの「いいね」を追加する(Activities::AdminFavoriteAdder)。
# フォームから受け取るのは件数だけで、対象の会員はサーバー側で決める。
class Admin::ActivityFavoriteAdditionsController < ApplicationController
  before_action :authenticate_admin!

  def create
    result = Activities::AdminFavoriteAdder.call(
      activity_id: params[:activity_id],
      count: params[:count],
      admin: current_admin
    )

    if result.success?
      redirect_to admin_activities_path, notice: "活動報告 ID #{params[:activity_id]} にいいねを#{result.added_ids.size}件追加しました。"
    else
      redirect_to admin_activities_path, alert: "活動報告 ID #{params[:activity_id]}: #{result.error}"
    end
  end
end
