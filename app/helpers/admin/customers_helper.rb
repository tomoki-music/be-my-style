module Admin::CustomersHelper
  ROLE_BADGE_COLORS = {
    admin: "danger",
    community_owner: "warning",
    manager: "info",
    general: "secondary"
  }.freeze

  # 一覧上の「管理者」はCustomer#is_ownerのenum(admin?)を指し、
  # 管理画面へログインするAdminモデル(current_admin)とは別概念。
  # オーナー/マネージャーはenumではなく実際の担当関連(CommunityOwner/owner_id、
  # CommunityEventEditor)を正として判定する。
  #
  # 管理者はBeMyStyleにおける最上位ロールのため、CommunityOwner/CommunityEventEditorの
  # 関連が残っていても一覧上は「管理者」のみを表示し、オーナー・マネージャーは併記しない。
  #
  # direct_owned_communities: Admin::HomesController#topで一括取得した
  # Community#owner_id経由の担当コミュニティ配列(customer単位)。
  def admin_customer_role_items(customer, direct_owned_communities = [])
    return [{ key: :admin, count: nil }] if customer.admin?

    items = []

    owner_count = admin_customer_owner_community_ids(customer, direct_owned_communities).size
    items << { key: :community_owner, count: owner_count } if owner_count.positive?

    manager_count = customer.community_event_editors.map(&:community_id).uniq.size
    items << { key: :manager, count: manager_count } if manager_count.positive?

    items << { key: :general, count: nil } if items.empty?

    items
  end

  def admin_customer_role_badges(customer, direct_owned_communities = [])
    badges = admin_customer_role_items(customer, direct_owned_communities).map do |item|
      content_tag(:span, role_badge(item[:key], item[:count]), class: "mr-1 mb-1")
    end

    content_tag(:div, safe_join(badges), class: "d-flex flex-wrap")
  end

  # メンバーの志向
  def member_type_badge(type)
    return badge("未設定", "secondary") if type.blank?

    label = I18n.t("enums.member_profile.suggested_member_type.#{type}", default: "未設定")

    color =
      case type
      when "challenge_member" then "danger"
      when "enjoy"     then "warning"
      when "growth"    then "primary"
      else "secondary"
      end

    badge(label, color)
  end

  # 🎸 音楽経験レベル
  def music_experience_badge(level)
    return badge("未設定", "secondary") if level.blank?

    label = I18n.t("enums.member_profile.music_experience_level.#{level}", default: "未設定")

    color =
      case level
      when "beginner"     then "info"
      when "hobby" then "primary"
      when "band"     then "danger"
      else "secondary"
      end

    badge(label, color)
  end

  # 🤝 関わり方
  def engagement_style_badge(style)
    return badge("未設定", "secondary") if style.blank?

    label = I18n.t("enums.member_profile.engagement_style.#{style}", default: "未設定")

    color =
      case style
      when "casual"   then "success"
      when "egular"  then "primary"
      when "challenge_active"    then "danger"
      else "secondary"
      end

    badge(label, color)
  end

  # 📩 連絡スタンス
  def contact_preference_badge(pref)
    return badge("未設定", "secondary") if pref.blank?

    label = I18n.t("enums.member_profile.contact_preference.#{pref}", default: "未設定")

    color =
      case pref
      when "lno_contact"    then "secondary"
      when "passive" then "info"
      when "welcome"   then "primary"
      else "secondary"
      end

    badge(label, color)
  end

  def domain_badges(customer)
    badges = []

    if customer.music_user?
      badges << content_tag(:span, class: "badge bg-primary me-1") do
        content_tag(:i, "", class: "bi bi-music-note-beamed me-1") + "音楽"
      end
    end

    if customer.business_user?
      badges << content_tag(:span, class: "badge bg-success") do
        content_tag(:i, "", class: "bi bi-briefcase me-1") + "ビジネス"
      end
    end

    if customer.learning_user?
      badges << content_tag(:span, class: "badge me-1", style: "background-color: #f59e0b; color: #ffffff;") do
        content_tag(:i, "", class: "bi bi-mortarboard me-1") + "学習"
      end
    end

    if customer.singing_user?
      badges << content_tag(:span, class: "badge me-1", style: "background-color: #7c3aed; color: #ffffff;") do
        content_tag(:i, "", class: "bi bi-mic me-1") + "歌唱・演奏診断"
      end
    end

    safe_join(badges)
  end

  private

  def admin_customer_owner_community_ids(customer, direct_owned_communities)
    association_community_ids = customer.community_owners.map(&:community_id)
    direct_owner_community_ids = direct_owned_communities.map(&:id)

    (association_community_ids + direct_owner_community_ids).compact.uniq
  end

  def role_badge(key, count)
    label = I18n.t("admin.customers.roles.#{key}")
    label = "#{label}（#{count}）" if count.present?

    badge(label, ROLE_BADGE_COLORS.fetch(key))
  end

  def badge(label, color)
    content_tag(:span, label, class: "badge badge-#{color} me-1")
  end
end
