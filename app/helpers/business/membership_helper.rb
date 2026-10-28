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
  end
end
