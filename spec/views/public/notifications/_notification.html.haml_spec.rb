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

  it "個別チャットのメンション通知(mention_dm)を表示し、リンクに対象メッセージのアンカーが含まれること" do
    visitor = create(:customer, name: "メンションする人")
    visited = create(:customer)
    chat_room = create(:chat_room)
    chat_message = create(:chat_message, :markdown, customer: visitor, chat_room: chat_room)
    notification = visitor.active_notifications.create!(
      visited: visited,
      action: "mention_dm",
      chat_message_id: chat_message.id
    )

    allow(view).to receive(:customer_avatar_tag).and_return("avatar".html_safe)

    render partial: "public/notifications/notification", locals: { notification: notification }

    expect(rendered).to include("メンションする人さん")
    expect(rendered).to include("個別チャットであなたを")
    expect(rendered).to include("メンション")
    expect(rendered).to include("chat_message_id=#{chat_message.id}")
  end

  it "コミュニティチャットのメンション通知(mention_community)を表示し、リンクに対象メッセージのアンカーが含まれること" do
    visitor = create(:customer, name: "メンションする人")
    visited = create(:customer)
    community = create(:community)
    chat_room = create(:chat_room)
    create(:chat_room_customer, chat_room: chat_room, customer: visited, community: community)
    chat_message = create(:chat_message, :markdown, customer: visitor, chat_room: chat_room, community: community)
    notification = visitor.active_notifications.create!(
      visited: visited,
      action: "mention_community",
      community_id: community.id,
      chat_message_id: chat_message.id
    )

    allow(view).to receive(:customer_avatar_tag).and_return("avatar".html_safe)

    render partial: "public/notifications/notification", locals: { notification: notification }

    expect(rendered).to include("メンションする人さん")
    expect(rendered).to include("コミュニティチャットであなたを")
    expect(rendered).to include("chat_message_id=#{chat_message.id}")
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
