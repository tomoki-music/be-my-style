class Admin::AnalyticsController < ApplicationController
  before_action :authenticate_admin!

  def show
    @summary_cards = [
      ["総ユーザー数", Customer.count],
      ["コミュニティ数", Community.count],
      ["活動報告数", Activity.count],
      ["イベント数", Event.count]
    ]

    @plan_stats = Customer.all.group_by(&:plan).transform_values(&:count).sort.to_h
    @confirmation_stats = {
      "メール認証済み" => Customer.where.not(confirmed_at: nil).count,
      "未認証" => Customer.where(confirmed_at: nil).count
    }
    @deleted_stats = {
      "利用中" => Customer.where(is_deleted: false).count,
      "退会済み" => Customer.where(is_deleted: true).count
    }
    @signup_stats = daily_counts(Customer, :created_at, 6)
    @content_stats = {
      "コミュニティ" => daily_counts(Community, :created_at, 6),
      "活動報告" => daily_counts(Activity, :created_at, 6),
      "イベント" => daily_counts(Event, :created_at, 6)
    }
  end

  private

  def daily_counts(model, column_name, days)
    range = days.days.ago.to_date..Date.current
    counts = model.where(column_name => range.begin.beginning_of_day..range.end.end_of_day)
                  .group("DATE(#{column_name})")
                  .count

    range.each_with_object({}) do |date, result|
      result[date.strftime("%m/%d")] = counts[date] || counts[date.to_s] || 0
    end
  end
end
