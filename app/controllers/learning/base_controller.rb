class Learning::BaseController < ApplicationController
  before_action :ensure_learning_access!

  private

  def ensure_learning_access!
    return if current_customer&.admin?
    return if current_customer&.learning_user?

    redirect_to root_path, alert: "学習ドメインの登録が必要です。"
  end
end
