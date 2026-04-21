module Admin::CustomersHelper
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

    safe_join(badges)
  end

  private

  def badge(label, color)
    content_tag(:span, label, class: "badge badge-#{color} me-1")
  end
end
