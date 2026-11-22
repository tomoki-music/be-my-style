# Business(NAKAMA)の通知設定。読み書きするのはログイン中の本人の設定だけ(他人の設定を指定する手段を持たない)。
class Business::NotificationSettingsController < ApplicationController
  layout "business"

  before_action :authenticate_customer!
  before_action :set_setting

  def show
  end

  def update
    if save_setting
      redirect_to business_notification_setting_path, notice: "通知設定を保存しました"
    else
      flash.now[:alert] = "通知設定を保存できませんでした"
      render :show, status: :unprocessable_entity
    end
  end

  private

  # 「現在」の表示は保存済みの値で出す(保存に失敗したときに、送られた値を現在の設定に見せない)。
  def set_setting
    @setting = current_customer.business_notification_setting_or_default
    @saved_email_enabled = @setting.email_enabled?
    @saved_in_app_enabled = @setting.in_app_enabled?
  end

  # 初回保存が同時に2回届いたときは、後の側を先に作られた行への更新に切り替える(customer_id の一意制約)。
  def save_setting
    @setting.update(setting_params)
  rescue ActiveRecord::RecordNotUnique
    @setting = current_customer.reload.business_notification_setting
    @setting.update(setting_params)
  end

  def setting_params
    params.require(:business_notification_setting).permit(:email_enabled, :in_app_enabled)
  end
end
