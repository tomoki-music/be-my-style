# スレッドの固定・解除。操作できるのはシステム管理者と親コミュニティのオーナー本人だけ
# (BusinessAccess#can_pin_project_thread?。ボタンの表示も同じ判定)。
class Business::ProjectThreadPinsController < ApplicationController
  include BusinessAccessControl

  before_action :set_project
  before_action :require_business_project_participant!
  before_action :set_thread
  before_action :ensure_thread_pinnable!

  # 固定済みのスレッドをもう一度固定しても、固定した日時(=固定スレッド内の順番)は変えない。
  def create
    @thread.update!(pinned_at: Time.current) unless @thread.pinned?
    redirect_back fallback_location: business_project_thread_path(@project, @thread), notice: "スレッドを固定しました"
  end

  def destroy
    @thread.update!(pinned_at: nil) if @thread.pinned?
    redirect_back fallback_location: business_project_thread_path(@project, @thread), notice: "スレッドの固定を解除しました"
  end

  private

  def set_project
    @project = find_business_project!(params[:project_id])
  end

  def set_thread
    @thread = @project.project_threads.find(params[:thread_id])
  end

  def ensure_thread_pinnable!
    return if current_customer.can_pin_project_thread?(@thread)

    redirect_to business_project_thread_path(@project, @thread),
      alert: "スレッドを固定・解除できるのは、システム管理者とコミュニティのオーナーだけです。"
  end
end
