class Admin::CustomerFeedbacksController < ApplicationController
  skip_before_action :authenticate_customer!
  skip_before_action :ensure_music_domain_access_for_public_routes!
  before_action :authenticate_admin!
  before_action :set_customer_feedback, only: [:show, :update]

  def index
    feedbacks = CustomerFeedback.includes(:customer).recent
    feedbacks = feedbacks.where(category: params[:category]) if CustomerFeedback.categories.key?(params[:category])
    feedbacks = feedbacks.where(status: params[:status]) if CustomerFeedback.statuses.key?(params[:status])

    @customer_feedbacks = feedbacks.page(params[:page]).per(20)
    # 未確認件数の表示は admin_unread_customer_feedback_count ヘルパー(1リクエスト1回 COUNT)に集約。
  end

  def show
  end

  def update
    if @customer_feedback.update(customer_feedback_params)
      redirect_to admin_customer_feedback_path(@customer_feedback), notice: "対応状況を更新しました。"
    else
      render :show
    end
  end

  private

  def set_customer_feedback
    @customer_feedback = CustomerFeedback.includes(:customer).find(params[:id])
  end

  # 運営が更新できるのは対応状況と管理者メモのみ。
  def customer_feedback_params
    params.require(:customer_feedback).permit(:status, :admin_note)
  end
end
