class Business::NotificationsController < ApplicationController
  layout "business"

  def index

    @notifications =
      current_customer
      .passive_notifications
      .for_business
      .order(created_at: :desc)

    # 一覧に出していない music 側の通知まで既読にしないよう、表示対象だけ既読にする。
    # 既読にする前の未読分は、この表示の間だけ「未読」として目印を付ける(既読化の対象・タイミングは従来どおり)。
    @unread_ids = @notifications.where(checked: false).pluck(:id).to_set
    @notifications.where(checked: false).update_all(checked: true)

  end
end
