class ApplicationController < ActionController::Base
  before_action :set_current_domain
  before_action :authenticate_customer!

  helper_method :current_domain

  private

  def set_current_domain
    if request.path.start_with?("/business")
      @current_domain = Domain.find_by(name: "business")
    else
      @current_domain = Domain.find_by(name: "music")
    end
  end

  def admin_only!
    redirect_to root_path, alert: "管理者のみ操作可能です。" unless current_customer&.admin?
  end

  def current_domain
    @current_domain
  end
end