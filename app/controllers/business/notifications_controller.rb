class Business::NotificationsController < ApplicationController
  def index

    @notifications =
      current_customer
      .passive_notifications
      .for_business
      .order(created_at: :desc)

    # 一覧に出していない music 側の通知まで既読にしないよう、表示対象だけ既読にする。
    @notifications.where(checked: false).update_all(checked: true)

  end
end
