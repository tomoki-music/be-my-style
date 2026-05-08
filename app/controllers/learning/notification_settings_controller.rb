class Learning::NotificationSettingsController < Learning::BaseController
  before_action :set_notification_setting

  def edit
  end

  def update
    attrs = notification_setting_params
    attrs[:delivery_channel] = "manual"

    if @notification_setting.update(attrs)
      redirect_to edit_learning_notification_settings_path, notice: "通知設定を保存しました。"
    else
      render :edit
    end
  end

  private

  def set_notification_setting
    @notification_setting = current_customer.learning_notification_setting ||
      current_customer.build_learning_notification_setting
  end

  def notification_setting_params
    params.require(:learning_notification_setting).permit(
      :reminder_enabled,
      :teacher_summary_enabled,
      :student_reactivation_enabled,
      :delivery_channel
    )
  end
end
