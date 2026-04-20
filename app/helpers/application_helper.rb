module ApplicationHelper
  def stamp_options
    Stampable::STAMP_OPTIONS
  end

  def stamp_label_for(stamp_type)
    stamp_options[stamp_type.to_s]
  end

  def prefecture_options_for_select
    Prefecture.all.reject { |prefecture| prefecture.id == 1 }.map { |prefecture| [prefecture.name, prefecture.id] }
  end

  def community_activity_stance_options
    Community.activity_stances.keys.map do |key|
      [I18n.t("activerecord.attributes.community/activity_stance.#{key}"), key]
    end
  end

  def community_sort_options
    [
      ["人気順", "members_desc"],
      ["新着順", "newest"]
    ]
  end

  def activity_sort_options
    [
      ["新着順", "newest"],
      ["人気順", "popular"]
    ]
  end

  def event_status_options
    [
      ["すべて", "all"],
      ["募集中", "recruiting"],
      ["開催前・開催中", "upcoming"],
      ["終了済み", "ended"]
    ]
  end

  def event_sort_options
    [
      ["開催日が近い順", "start_soon"],
      ["新着順", "newest"],
      ["開催日が遠い順", "start_later"]
    ]
  end

  def admin?
    customer_signed_in? && current_customer.admin?
  end

  def feature_locked_badge(feature_key)
    required_plan = ApplicationController::FEATURE_CATALOG.fetch(feature_key.to_sym)[:required_plan]
    "#{required_plan.upcase}で開放"
  end

  def customer_plan_label(customer)
    customer.plan_badge_label
  end

  def customer_role_badge_label(customer)
    return if customer.blank?
    return "管理者" if customer.respond_to?(:admin?) && customer.admin?
    return "オーナー" if customer.respond_to?(:community_owner?) && customer.community_owner?

    nil
  end

  def customer_avatar_tag(customer, class_name: nil, wrapper_class: nil, fallback: "no_image")
    image_source =
      if customer&.profile_image.respond_to?(:attached?) && customer.profile_image.attached?
        customer.profile_image
      elsif customer&.profile_image.present?
        customer.profile_image
      else
        fallback
      end

    badge_label = customer_role_badge_label(customer)
    badge_class =
      case badge_label
      when "管理者"
        "avatar-role-badge avatar-role-badge--admin"
      when "オーナー"
        "avatar-role-badge avatar-role-badge--owner"
      end

    content_tag(:span, class: ["avatar-with-badge", wrapper_class].compact.join(" ")) do
      concat image_tag(image_source, class: class_name)
      concat(content_tag(:span, badge_label, class: badge_class)) if badge_label.present?
    end
  end

  def subscription_checkout_path_for(plan)
    if request.path.start_with?("/business")
      business_checkout_path(plan)
    else
      public_checkout_path(plan)
    end
  end

  def subscription_portal_path_for_current_domain
    if request.path.start_with?("/business")
      business_portal_path
    else
      public_portal_path
    end
  end
  
  def enum_filter_options(enum_hash, i18n_scope)
    [["全て", ""]] +
      enum_hash.keys.map { |k| [I18n.t("#{i18n_scope}.#{k}"), k] }
  end
  
  def html_safe_newline(str)
    h(str).gsub(/\n|\r|\r\n/, "<br>").html_safe
  end
  
end
