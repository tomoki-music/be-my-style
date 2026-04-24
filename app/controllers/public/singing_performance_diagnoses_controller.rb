class Public::SingingPerformanceDiagnosesController < ApplicationController
  before_action :ensure_music_access!

  def show
  end

  private

  def ensure_music_access!
    return if current_customer&.admin?
    return if current_customer&.music_user?

    redirect_to root_path, alert: "音楽ドメインの登録が必要です。"
  end
end
