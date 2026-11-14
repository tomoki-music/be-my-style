module Business
  module ProjectHelper
    # 進行状況の表示名。編集フォームの選択肢と同じ文言にする。
    PROJECT_STATUS_LABELS = {
      "recruiting" => "募集中",
      "active" => "進行中",
      "completed" => "終了"
    }.freeze

    # 公開範囲の表示名。編集フォームの選択肢と、限定公開・プライベートのしるしで同じ文言にする。
    PROJECT_VISIBILITY_LABELS = {
      "listed" => "通常公開",
      "unlisted" => "限定公開",
      "private" => "プライベート"
    }.freeze

    # スレッドを作成できる人の表示名。編集フォームの選択肢と、権限の無い人向けの表示で同じ文言にする。
    PROJECT_THREAD_CREATION_LABELS = {
      "owners_only" => "管理者・オーナーのみ",
      "managers" => "運営者まで",
      "all_members" => "参加メンバー全員"
    }.freeze

    def business_project_thread_creation_options
      PROJECT_THREAD_CREATION_LABELS.map { |value, label| [label, value] }
    end

    def business_project_thread_creation_label(project)
      PROJECT_THREAD_CREATION_LABELS.fetch(project.thread_creation_policy.to_s, project.thread_creation_policy.to_s)
    end

    # include_private: プライベートを選べる人(システム管理者・親コミュニティのオーナー)だけ true。
    def business_project_visibility_options(include_private: false)
      labels = include_private ? PROJECT_VISIBILITY_LABELS : PROJECT_VISIBILITY_LABELS.except("private")
      labels.map { |value, label| [label, value] }
    end

    # 一覧・詳細に出す公開範囲のしるし(通常公開には出さない)。
    def business_project_visibility_badge(project)
      return if project.visibility_listed?

      icon = project.visibility_private? ? "fa-solid fa-lock" : "fa-solid fa-eye-slash"
      tag.span(class: ["ba-status", "ba-status--#{project.visibility_private? ? 'private' : 'unlisted'}"]) do
        safe_join([tag.i(class: icon, "aria-hidden": "true"), business_project_visibility_label(project)], " ")
      end
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
