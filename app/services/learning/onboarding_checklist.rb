# frozen_string_literal: true

module Learning
  class OnboardingChecklist
    Item = Struct.new(:key, :title, :description, :completed, :cta_label, :cta_path, keyword_init: true) do
      def completed?
        completed
      end
    end

    def initialize(customer, routes:)
      @customer = customer
      @routes = routes
    end

    def items
      [
        students_registered_item,
        line_connected_item,
        templates_ready_item,
        assignment_created_item,
        auto_reminder_previewed_item,
        auto_reminder_enabled_item
      ]
    end

    def completed_count
      items.count(&:completed)
    end

    def total_count
      items.count
    end

    def completed?
      items.all?(&:completed)
    end

    private

    attr_reader :customer, :routes

    def students_registered_item
      Item.new(
        key: :students_registered,
        title: "生徒を登録する",
        description: "まず部員を1人登録すると、課題配布とLINE連携の準備を始められます。",
        completed: active_student_count.positive?,
        cta_label: active_student_count.positive? ? "生徒一覧を見る" : "生徒を追加",
        cta_path: active_student_count.positive? ? routes.learning_students_path : routes.new_learning_student_path
      )
    end

    def line_connected_item
      Item.new(
        key: :line_connected,
        title: "LINE連携QRを配布する",
        description: "LINE連携済みの生徒がいると、一括LINEや自動リマインドの対象になります。",
        completed: line_connected_count.positive?,
        cta_label: line_connected_count.positive? ? "連携状況を見る" : "QRを配布",
        cta_path: first_student_line_connection_path || routes.learning_students_path
      )
    end

    def templates_ready_item
      Item.new(
        key: :templates_ready,
        title: "通知テンプレートを確認する",
        description: "要フォローや課題未提出の文面を先に整えると、送信前確認が楽になります。",
        completed: active_template_count.positive?,
        cta_label: "テンプレートを見る",
        cta_path: routes.learning_line_message_templates_path
      )
    end

    def assignment_created_item
      Item.new(
        key: :assignment_created,
        title: "課題を1つ作成する",
        description: "最初は小さな課題で十分です。生徒が今日やることを確認できる状態にします。",
        completed: assignment_count.positive?,
        cta_label: assignment_count.positive? ? "課題進捗を見る" : "課題を配布",
        cta_path: assignment_count.positive? ? routes.learning_assignments_path : routes.learning_students_path
      )
    end

    def auto_reminder_previewed_item
      Item.new(
        key: :auto_reminder_previewed,
        title: "自動リマインドをプレビューする",
        description: "いきなり送信されません。対象者と文面を見てからONにできます。",
        completed: false,
        cta_label: "プレビューを見る",
        cta_path: routes.learning_auto_reminders_path
      )
    end

    def auto_reminder_enabled_item
      Item.new(
        key: :auto_reminder_enabled,
        title: "自動リマインドをONにする",
        description: "慣れてきたらONにします。OFFの間は自動送信されないので安心です。",
        completed: notification_setting.auto_reminder_enabled?,
        cta_label: notification_setting.auto_reminder_enabled? ? "設定を確認" : "設定する",
        cta_path: routes.edit_learning_notification_settings_path
      )
    end

    def active_student_count
      @active_student_count ||= customer.learning_students.active.count
    end

    def first_student
      @first_student ||= customer.learning_students.active.ordered.first
    end

    def line_connected_count
      @line_connected_count ||= customer.learning_students
        .active
        .joins(:learning_line_connections)
        .merge(Learning::LineConnection.connected)
        .distinct
        .count
    end

    def active_template_count
      @active_template_count ||= customer.learning_line_message_templates.active.count
    end

    def assignment_count
      @assignment_count ||= customer.learning_assignments.count
    end

    def notification_setting
      @notification_setting ||= Learning::NotificationSetting.effective_for(customer)
    end

    def first_student_line_connection_path
      return nil unless first_student

      routes.learning_student_line_connection_path(first_student)
    end
  end
end
