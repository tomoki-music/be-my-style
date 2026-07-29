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

  it "イベントリクエストのメンション通知(mention_request)を表示し、投稿者名・イベント名・「メンションしました」の文言・対象イベントへのリンクが含まれること" do
    visitor = create(:customer, name: "メンションする人")
    visited = create(:customer)
    event = create(:event, :event_with_songs, event_name: "秋の音楽祭")
    notification = visitor.active_notifications.create!(
      visited: visited,
      action: "mention_request",
      event_id: event.id
    )

    allow(view).to receive(:customer_avatar_tag).and_return("avatar".html_safe)

    render partial: "public/notifications/notification", locals: { notification: notification }

    expect(rendered).to include("メンションする人さん")
    expect(rendered).to include("秋の音楽祭")
    expect(rendered).to include("みんなのリクエスト")
    expect(rendered).to include("であなたをメンションしました")
    expect(rendered).to include(public_event_path(event))
  end

  it "mention_request通知は、通常のリクエスト投稿通知(request-msg)と表示が区別できること" do
    visitor = create(:customer, name: "投稿する人")
    visited = create(:customer)
    event = create(:event, :event_with_songs)

    request_msg_notification = visitor.active_notifications.create!(
      visited: visited, action: "request-msg", event_id: event.id
    )
    allow(view).to receive(:customer_avatar_tag).and_return("avatar".html_safe)
    render partial: "public/notifications/notification", locals: { notification: request_msg_notification }
    expect(rendered).not_to include("メンションしました")

    Notification.where(visited_id: visited.id).destroy_all
    mention_notification = visitor.active_notifications.create!(
      visited: visited, action: "mention_request", event_id: event.id
    )
    render partial: "public/notifications/notification", locals: { notification: mention_notification }
    expect(rendered).to include("メンションしました")
  end

  it "イベント名に含まれるHTMLがエスケープされること(XSS対策)" do
    visitor = create(:customer, name: "メンションする人")
    visited = create(:customer)
    event = create(:event, :event_with_songs, event_name: "<script>alert(1)</script>")
    notification = visitor.active_notifications.create!(
      visited: visited,
      action: "mention_request",
      event_id: event.id
    )

    allow(view).to receive(:customer_avatar_tag).and_return("avatar".html_safe)

    render partial: "public/notifications/notification", locals: { notification: notification }

    expect(rendered).not_to include("<script>alert(1)</script>")
    expect(rendered).to include("&lt;script&gt;")
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
