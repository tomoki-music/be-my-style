class Public::CustomerFeedbacksController < ApplicationController
  before_action :authenticate_customer!

  # 自分の送信履歴のみ。current_customer 起点で引くことで他人の投稿は構造的に見えない。
  def index
    @customer_feedbacks = current_customer.customer_feedbacks
                                          .recent
                                          .page(params[:page])
                                          .per(10)
  end

  def new
    @customer_feedback = current_customer.customer_feedbacks.new
  end

  def create
    @customer_feedback = current_customer.customer_feedbacks.new(customer_feedback_params)

    if @customer_feedback.save
      # 二重送信防止のため callback ではなく save 成功後にここでのみ通知する。
      AdminCustomerFeedbackNotifier.call(@customer_feedback)
      redirect_to public_customer_feedbacks_path,
                  notice: "ご意見を送信しました。ご協力ありがとうございます！"
    else
      render :new
    end
  end

  private

  # customer_id / status / admin_note は受け取らない。customer は current_customer 固定。
  def customer_feedback_params
    permitted = params.require(:customer_feedback).permit(:category, :subject, :body)
    # 不正な category(enum 外)は ArgumentError を避けて nil 化し、presence バリデーションで弾く。
    permitted[:category] = nil unless CustomerFeedback.categories.key?(permitted[:category].to_s)
    permitted
  end
end
