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

  it "singingプロフィール応援リアクション通知を表示できること" do
    visitor = create(:customer, domain_name: "singing", name: "応援する人")
    visited = create(:customer, domain_name: "singing")
    notification = visitor.active_notifications.create!(
      visited: visited,
      action: "singing_profile_reaction_cheer"
    )

    allow(view).to receive(:customer_avatar_tag).and_return("avatar".html_safe)

    render partial: "public/notifications/notification", locals: { notification: notification }

    expect(rendered).to include("応援する人さん")
    expect(rendered).to include("あなたのプロフィール")
    expect(rendered).to include("『応援してます！』を送りました")
    expect(rendered).to include(singing_user_path(visited))
  end
end
