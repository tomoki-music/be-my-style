module Business
  # コミュニティ・プロジェクトの参加方式と参加状況の表示文言。
  module MembershipHelper
    JOIN_APPROVAL_LABELS = {
      "manual" => "承認制",
      "auto" => "自動承認"
    }.freeze

    JOIN_APPROVAL_DESCRIPTIONS = {
      "manual" => "参加申請を運営者が承認すると参加できます。",
      "auto" => "「参加する」を押すとすぐに参加できます。"
    }.freeze

    def business_join_approval_label(record)
      JOIN_APPROVAL_LABELS.fetch(record.join_approval_mode)
    end

    def business_join_approval_description(record)
      JOIN_APPROVAL_DESCRIPTIONS.fetch(record.join_approval_mode)
    end

    def business_join_approval_options
      JOIN_APPROVAL_LABELS.map { |mode, label| ["#{label}（#{JOIN_APPROVAL_DESCRIPTIONS[mode]}）", mode] }
    end

    def business_join_button_label(record)
      record.join_auto? ? "参加する" : "参加を申請する"
    end

    # Business::Memberships::CommunityStatuses / ProjectStatuses の状態ごとの表示(文言・アイコン・色)。
    # :none(未参加)はバッジではなく参加ボタンを出すため含めない。
    JOIN_STATUS_BADGES = {
      operator: ["運営", "fa-solid fa-star", "manager"],
      owner: ["主催", "fa-solid fa-star", "owner"],
      admin: ["管理権限あり", "fa-solid fa-shield-halved", "manager"],
      member: ["参加中", "fa-solid fa-check", "member"],
      suspended: ["アクセス停止中", "fa-solid fa-ban", "suspended"],
      pending: ["承認待ち", "fa-regular fa-clock", "pending"],
      closed: ["募集終了", "fa-solid fa-circle-minus", nil]
    }.freeze

    def business_join_status_badge(status)
      label, icon, modifier = JOIN_STATUS_BADGES.fetch(status)
      tag.span(class: ["ba-status", ("ba-status--#{modifier}" if modifier)]) do
        safe_join([tag.i(class: icon, "aria-hidden": "true"), label], " ")
      end
    end
  end
end
