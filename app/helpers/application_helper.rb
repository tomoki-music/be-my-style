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

  # 常時表示のシンプルなピル型ピッカー(活動コメント・法人投稿コメント)用の一覧
  # ({ key => 表示名 })。3タブ化したリクエスト/チャットのピッカーとは別物で、
  # ここではシンプルカテゴリ(既存SVG 10種)のみを出す。レガシー絵文字は含めない。
  def stamp_options
    Stampable::STAMP_DEFINITIONS
      .select { |_key, definition| definition[:category] == :simple }
      .transform_values { |definition| definition[:label] }
  end

  # リクエスト/チャットの3タブピッカー用。{ category => { key => { label:, asset:, category: } } }。
  def stamp_choices_by_category
    Stampable.definitions_by_category
  end

  # 管理画面のスタンプ select 用のグループ化オプション。全カテゴリを扱い、
  # 編集対象レコードがレガシー(絵文字)キーを持つ場合はそのキーも選択肢に残して、
  # 保存時に不用意に消えないようにする。
  def stamp_select_options(current_stamp_type = nil)
    grouped = Stampable::STAMP_CATEGORY_LABELS.map do |category, category_label|
      choices = Stampable::STAMP_DEFINITIONS
                .select { |_key, definition| definition[:category] == category }
                .map { |key, definition| ["#{definition[:label]}（#{key}）", key] }
      [category_label, choices]
    end

    key = current_stamp_type.to_s
    if key.present? && !Stampable::STAMP_DEFINITIONS.key?(key)
      legacy_label = Stampable::LEGACY_STAMP_LABELS[key] || key
      grouped << ["以前のスタンプ", [["#{legacy_label}（#{key}）", key]]]
    end

    grouped
  end

  # 保存値から表示名を解決する。新イラスト・レガシー絵文字のどちらのキーにも対応。
  def stamp_label_for(stamp_type)
    key = stamp_type.to_s
    Stampable::STAMP_DEFINITIONS.dig(key, :label) || Stampable::LEGACY_STAMP_LABELS[key]
  end

  # イラストスタンプの画像タグ。パスは定義から解決し、alt には表示名を入れる。
  # イラストスタンプでないキー(レガシー絵文字・不正値)の場合は nil を返す。
  def stamp_image_tag(stamp_type, html_options = {})
    definition = Stampable::STAMP_DEFINITIONS[stamp_type.to_s]
    return if definition.blank?

    image_tag(definition[:asset], html_options.reverse_merge(alt: definition[:label]))
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
      if show_active_status
        concat(avatar_active_status_dot(customer_login_activity_level(customer), image_class_name: class_name))
      end
    end
  end

  # プロフィール / マイページ等で表示する「大きなユーザー画像」の共通表示。
  # 枠のサイズ・角丸は呼び出し側（frame_class）で既存デザインに合わせて指定し、
  # はみ出し防止・アスペクト比維持・中央トリミングは .user-profile-image /
  # .user-profile-image-frame（application.scss）へ一本化する。
  def customer_profile_image_tag(customer, frame_class: nil, fallback: "no_image", show_active_status: true)
    customer_avatar_tag(
      customer,
      class_name: "user-profile-image",
      wrapper_class: ["user-profile-image-frame", frame_class].compact.join(" "),
      fallback: fallback,
      show_active_status: show_active_status
    )
  end

  # 退会済み・未ログイン・Customer 以外のオブジェクトはアクティブ扱いしない。
  # 戻り値は :active / :semi / :dormant / nil。
  def customer_login_activity_level(customer)
    return nil if customer_withdrawn?(customer)
    return nil unless customer.respond_to?(:login_activity_level)

    customer.login_activity_level
  end

  AVATAR_ACTIVE_STATUS_LABELS = {
    active: "24時間以内にログイン",
    semi: "1週間以内にログイン",
    dormant: "1か月以内にログイン"
  }.freeze

  # 丸を 10px（--small）に縮める小サイズアバターの画像クラス。
  # 各クラスの実寸（28〜38px）は対応する SCSS で定義済みで、ここはその
  # 「既存のサイズ情報」を参照するだけ。通常サイズ（icon_mini=50px 等）は 14px のまま。
  SMALL_AVATAR_IMAGE_CLASSES = %w[
    activity-card-avatar
    singing-ranking__user-avatar
    singing-ranking__growth-user-avatar
    singing-season__user-avatar
    cheers-history__avatar-img
  ].freeze

  # アクティブ状態を表す丸（緑 / 黄 / 灰）。色だけで状態が伝わらないよう、
  # title / aria-label / role を付与する。正確なログイン日時は出さない。
  # level が nil（対象外）のときは何も描画しない。
  # image_class_name: アバター画像の class。小サイズ指定なら丸も小さくする。
  def avatar_active_status_dot(level, image_class_name: nil)
    label = AVATAR_ACTIVE_STATUS_LABELS[level&.to_sym]
    return if label.blank?

    classes = ["avatar-active-dot", "avatar-active-dot--#{level}"]
    classes << "avatar-active-dot--small" if avatar_class_small?(image_class_name)

    content_tag(
      :span,
      "",
      class: classes.join(" "),
      title: label,
      "aria-label": label,
      role: "img"
    )
  end

  def avatar_class_small?(image_class_name)
    return false if image_class_name.blank?

    (image_class_name.to_s.split & SMALL_AVATAR_IMAGE_CLASSES).any?
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
