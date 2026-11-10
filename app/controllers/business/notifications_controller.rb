class Business::NotificationsController < ApplicationController
  layout "business"

  def index

    @notifications =
      current_customer
      .passive_notifications
      .for_business
      .shown_in_app
      .includes(:visitor, :community, project: :community, project_chat: :project_thread)
      .order(created_at: :desc)
    @viewable_project_ids = viewable_project_ids(@notifications)

    # 一覧に出していない music 側の通知まで既読にしないよう、表示対象だけ既読にする。
    # 既読にする前の未読分は、この表示の間だけ「未読」として目印を付ける(既読化の対象・タイミングは従来どおり)。
    @unread_ids = @notifications.where(checked: false).pluck(:id).to_set
    @notifications.where(checked: false).update_all(checked: true)

  end

  private

  # スレッド投稿の通知は、いまプロジェクト内部を閲覧できる場合だけ名前・リンクを出す(退出・停止後に内部情報を見せない)。
  def viewable_project_ids(notifications)
    projects = notifications.select { |notification| notification.action == "project_message" }.filter_map(&:project).uniq
    projects.select { |project| current_customer.business_project_participant?(project) }.map(&:id).to_set
  end
end
