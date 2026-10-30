module Business
  # ログイン後の Business 画面の全体ナビゲーション(PC の左ナビ / SP の下部ナビ・メニュー)。
  # 項目は既存の画面だけで、表示してよいかの判定(投稿のプラン制限など)も既存の feature_available? に揃える。
  module NavigationHelper
    def business_nav_items(unread_count)
      [
        { key: :home, label: "ホーム", icon: "fa-house", path: business_root_path },
        { key: :communities, label: "コミュニティ", icon: "fa-users", path: business_communities_path },
        { key: :projects, label: "プロジェクト", icon: "fa-layer-group", path: business_projects_path },
        { key: :timeline, label: "タイムライン", icon: "fa-stream", path: business_timeline_path },
        { key: :posts, label: "投稿", icon: "fa-pen-to-square", path: business_posts_path,
          locked: !feature_available?(:business_post_create) },
        { key: :notifications, label: "通知", icon: "fa-bell", path: business_notifications_path,
          badge: unread_count, data: { turbolinks: false } }
      ]
    end

    # SP の下部ナビに常時出す項目。残り(タイムライン・投稿・アカウント)は「メニュー」にまとめる。
    BOTTOM_NAV_KEYS = %i[home communities projects notifications].freeze

    def business_bottom_nav_items(items)
      items.select { |item| BOTTOM_NAV_KEYS.include?(item[:key]) }
    end

    def business_menu_nav_items(items)
      items.reject { |item| BOTTOM_NAV_KEYS.include?(item[:key]) }
    end

    # 現在地。プロジェクト配下(スレッドを含む)は「プロジェクト」、コミュニティの管理画面は「コミュニティ」に含める。
    def business_nav_section
      case controller_name
      when "homes" then :home
      when "communities", "community_project_managements" then :communities
      when "projects", "project_threads" then :projects
      when "posts" then action_name == "timeline" ? :timeline : :posts
      when "notifications" then :notifications
      when "customers" then :account
      end
    end

    def business_nav_current?(key)
      business_nav_section == key
    end

    def business_nav_badge_label(count)
      count.to_i.positive? ? "（未読#{count}件）" : ""
    end

    # 画像が無いコミュニティ・プロジェクトの代替表示に使う頭文字と色。色は id から決め、表示のたびに変わらないようにする。
    MONOGRAM_TONES = %w[blue peach sky mist].freeze

    def business_monogram(name, id: nil, size: nil, shape: :circle)
      initial = name.to_s.strip[0].presence || "?"
      tone = MONOGRAM_TONES[id.to_i % MONOGRAM_TONES.size]
      classes = ["ba-monogram", "ba-monogram--#{tone}", "ba-monogram--#{shape}"]
      classes << "ba-monogram--#{size}" if size
      tag.span(initial, class: classes, "aria-hidden": "true")
    end

    # 丸いコミュニティ画像。画像が無ければ頭文字で代替する。
    def business_community_avatar(community, size: nil)
      if community.community_image.attached?
        classes = ["ba-avatar", "ba-avatar--image"]
        classes << "ba-avatar--#{size}" if size
        image_tag community.community_image, class: classes, alt: "", loading: "lazy"
      else
        business_monogram(community.name, id: community.id, size: size)
      end
    end
  end
end
