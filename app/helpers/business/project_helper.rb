module Business
  module ProjectHelper
    # 進行状況の表示名。編集フォームの選択肢と同じ文言にする。
    PROJECT_STATUS_LABELS = {
      "recruiting" => "募集中",
      "active" => "進行中",
      "completed" => "終了"
    }.freeze

    # 公開範囲の表示名。編集フォームの選択肢と、限定公開のしるしで同じ文言にする。
    PROJECT_VISIBILITY_LABELS = {
      "listed" => "通常公開",
      "unlisted" => "限定公開"
    }.freeze

    def business_project_visibility_options
      PROJECT_VISIBILITY_LABELS.map { |value, label| [label, value] }
    end

    def business_project_visibility_label(project)
      PROJECT_VISIBILITY_LABELS.fetch(project.visibility.to_s, project.visibility.to_s)
    end

    def business_project_status_options
      PROJECT_STATUS_LABELS.map { |value, label| [label, value] }
    end

    def business_project_status_label(project)
      PROJECT_STATUS_LABELS.fetch(project.status.to_s, project.status.to_s)
    end
  end
end
