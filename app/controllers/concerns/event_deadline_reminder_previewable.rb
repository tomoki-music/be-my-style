# イベント作成・編集フォームの「締め切り自動リマインド」の保存前プレビュー(公開画面・管理画面共通)。
# 入力中の値を未保存の Event / リマインドに当てはめて表示用HTMLを返すだけで、保存・送信は一切しない。
# 権限チェックは各コントローラーの before_action(編集・作成と同じもの)で行う。
module EventDeadlineReminderPreviewable
  extend ActiveSupport::Concern

  PREVIEW_EVENT_ATTRIBUTES = %i[
    event_name event_start_time event_end_time event_entry_deadline request_deadline entrance_fee place
  ].freeze
  PREVIEW_REMINDER_ATTRIBUTES = %i[enabled channel lead_hours custom_message].freeze

  private

  def render_deadline_reminder_preview(event)
    kind = params.dig(:reminder, :kind).to_s
    unless EventDeadlineReminder.kinds.key?(kind)
      render json: { error: "締め切りの種別が不正です" }, status: :unprocessable_entity
      return
    end

    event.assign_attributes(params.fetch(:event, {}).permit(*PREVIEW_EVENT_ATTRIBUTES))
    reminder = event.deadline_reminder_for(kind)
    reminder.assign_attributes(params.fetch(:reminder, {}).permit(*PREVIEW_REMINDER_ATTRIBUTES))
    preview = EventDeadlineReminders::FormPreview.new(event: event, reminder: reminder)
    preview.errors

    render json: {
      status_html: render_to_string(partial: "public/events/deadline_reminder_status", formats: [:html], locals: { preview: preview }),
      message_html: render_to_string(partial: "public/events/deadline_reminder_message", formats: [:html], locals: { preview: preview }),
      auto_body: preview.message&.auto_body
    }
  end
end
