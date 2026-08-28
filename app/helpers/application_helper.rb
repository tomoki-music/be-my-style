module ApplicationHelper
  WITHDRAWN_CUSTOMER_LABEL = "退会済みユーザー".freeze

  # 一般・公開画面で「退会済みユーザーを現役ユーザーとして表示しない」ために使う共通判定。
  # is_deletedカラム自体は削除しないため、表示側のガードとしてのみ使う。
  def customer_withdrawn?(customer)
    customer.present? && customer.respond_to?(:is_deleted?) && customer.is_deleted?
  end

  # 退会済みなら固定ラベル、それ以外は通常の名前を返す。
  # コメント・チャット・メンバー一覧など「名前だけ」表示したい箇所で使う。
  def customer_display_name(customer)
    return WITHDRAWN_CUSTOMER_LABEL if customer_withdrawn?(customer)

    customer&.name
  end

  # 退会済みなら名前のみ(リンクなし)、それ以外は既存どおりプロフィールへのリンクを返す。
  # profile_path: businessドメイン等、public_customer_path以外のプロフィールURLを使う画面向け。
  def customer_profile_name_link(customer, html_options = {}, profile_path: nil)
    if customer_withdrawn?(customer)
      content_tag(:span, WITHDRAWN_CUSTOMER_LABEL, html_options)
    else
      link_to customer.name, profile_path || public_customer_path(customer), html_options.merge(data: { 'turbolinks': false })
    end
  end

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
      ["開催日が古い順", "start_soon"],
      ["新着順", "newest"],
      ["開催日が新しい順", "start_later"]
    ]
  end

  def admin?
    customer_signed_in? && current_customer.admin?
  end

  def feature_locked_badge(feature_key)
    required_plan = ApplicationController::FEATURE_CATALOG.fetch(feature_key.to_sym)[:required_plan]
    "#{required_plan.capitalize}プラン契約で解放"
  end

  def customer_plan_label(customer)
    customer.plan_badge_label
  end

  def customer_plan_badge_class(customer)
    "plan-badge-inline plan-badge-inline--#{customer.plan}"
  end

  def customer_role_badge_label(customer)
    return if customer.blank?
    return if customer_withdrawn?(customer)
    return "管理者" if customer.respond_to?(:admin?) && customer.admin?
    return "オーナー" if customer.respond_to?(:community_owner?) && customer.community_owner?
    return "マネージャー" if customer.respond_to?(:manager?) && customer.manager?

    nil
  end

  # show_active_status: 最近アクティブなユーザーに緑丸を表示するか。
  # チャットのメッセージ一覧など、常時表示すると煩雑になる箇所では false を渡す。
  def customer_avatar_tag(customer, class_name: nil, wrapper_class: nil, fallback: "no_image", show_active_status: true)
    image_source =
      if customer_withdrawn?(customer)
        fallback
      elsif customer&.profile_image.respond_to?(:attached?) && customer.profile_image.attached?
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
      when "マネージャー"
        "avatar-role-badge avatar-role-badge--manager"
      end

    content_tag(:span, class: ["avatar-with-badge", wrapper_class].compact.join(" ")) do
      concat image_tag(image_source, class: class_name)
      concat(content_tag(:span, badge_label, class: badge_class)) if badge_label.present?
      concat(avatar_active_status_dot) if show_active_status && customer_recently_active?(customer)
    end
  end

  # 退会済み・未ログイン・Customer 以外のオブジェクトはアクティブ扱いしない。
  def customer_recently_active?(customer)
    return false if customer_withdrawn?(customer)

    customer.respond_to?(:recently_active?) && customer.recently_active?
  end

  # 「最近アクティブ」を表す緑丸。色だけで状態が伝わらないよう、
  # title / aria-label / role を付与する。正確なログイン日時は出さない。
  def avatar_active_status_dot
    content_tag(
      :span,
      "",
      class: "avatar-active-dot",
      title: "最近アクティブ",
      "aria-label": "最近アクティブ",
      role: "img"
    )
  end

  # アバター画像を、退会済みならプロフィールへ遷移させない形で描画する。
  # 「アバターにプロフィールリンクを貼る」既存パターン(コミュニティ/イベント/コメント等)を
  # 共通化したもの。リンクテキストが名前のみの箇所はcustomer_profile_name_linkを使う。
  # profile_path: businessドメイン等、public_customer_path以外のプロフィールURLを使う画面向け。
  def customer_avatar_link(customer, class_name: nil, wrapper_class: nil, fallback: "no_image", profile_path: nil)
    avatar = customer_avatar_tag(customer, class_name: class_name, wrapper_class: wrapper_class, fallback: fallback)
    return avatar if customer_withdrawn?(customer)

    link_to avatar, profile_path || public_customer_path(customer), data: { 'turbolinks': false }
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

  def learning_nav_active?(path)
    current_path = request.path
    current_path == path || current_path.start_with?("#{path}/")
  end

  def learning_school_group_options(school_groups)
    Array(school_groups).map { |group| [group.name, group.id] }
  end
  
  def enum_filter_options(enum_hash, i18n_scope)
    [["全て", ""]] +
      enum_hash.keys.map { |k| [I18n.t("#{i18n_scope}.#{k}"), k] }
  end
  
  def html_safe_newline(str)
    h(str).gsub(/\n|\r|\r\n/, "<br>").html_safe
  end
  
end
