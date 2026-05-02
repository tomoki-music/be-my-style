require 'rails_helper'

RSpec.describe "public/notifications/_notification", type: :view do
  it "reaction通知をリアクション絵文字付きで表示できること" do
    visitor = create(:customer, name: "リアクションする人")
    visited = create(:customer)
    activity = create(:activity, customer: visited)
    notification = visitor.active_notifications.create!(
      visited: visited,
      action: "reaction_fire",
      activity_id: activity.id
    )

    allow(view).to receive(:customer_avatar_tag).and_return("avatar".html_safe)

    render partial: "public/notifications/notification", locals: { notification: notification }

    expect(rendered).to include("リアクションする人さん")
    expect(rendered).to include("あなたの活動ログ")
    expect(rendered).to include("🔥応援しました")
  end
end
