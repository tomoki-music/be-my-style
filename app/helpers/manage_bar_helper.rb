# 通常画面・編集画面・メンバー管理画面で共通の「管理メニュー」の項目。
# どの画面でも同じ並びにして、管理者が今どの画面にいるかを current で示す。
# 表示してよいか(権限)は呼び出し側で判定し、リンク先でもサーバー側で認可する。
module ManageBarHelper
  def business_community_manage_items(community, current:, pending_count: nil)
    [
      manage_bar_item("通常画面", business_community_path(community), current == :show),
      manage_bar_item("編集", edit_business_community_path(community), current == :edit),
      manage_bar_item("メンバー管理", business_permits_path(community), current == :members, badge: pending_count)
    ]
  end

  # 音楽コミュニティの画面は Turbolinks を切って遷移している(既存のリンクに揃える)。
  def music_community_manage_items(community, current:, pending_count: nil)
    data = { turbolinks: false }
    [
      manage_bar_item("通常画面", public_community_path(community), current == :show, data: data),
      manage_bar_item("編集", edit_public_community_path(community), current == :edit, data: data),
      manage_bar_item("メンバー管理", public_permits_path(community), current == :members, badge: pending_count, data: data)
    ]
  end

  def business_project_manage_items(project, current:, pending_count: nil)
    [
      manage_bar_item("通常画面", business_project_path(project), current == :show),
      manage_bar_item("編集", edit_business_project_path(project), current == :edit),
      manage_bar_item("メンバー管理", members_business_project_path(project), current == :members, badge: pending_count)
    ]
  end

  private

  def manage_bar_item(label, path, current, badge: nil, data: {})
    { label: label, path: path, current: current, badge: badge, data: data }
  end
end
