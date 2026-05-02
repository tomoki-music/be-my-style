class Singing::BaseController < ApplicationController
  layout "singing"
  before_action :ensure_singing_access!

  private

  def ensure_singing_access!
    return if current_customer&.admin?
    return if current_customer&.singing_user?
    return if current_customer&.music_user?

    redirect_to root_path, alert: "音楽または歌唱・演奏診断ドメインの登録が必要です。"
  end
end
