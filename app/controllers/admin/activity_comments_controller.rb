class Admin::ActivityCommentsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_comment, only: [:show, :edit, :update, :destroy]

  def index
    @comments = Comment.includes(:customer, :activity).order(created_at: :desc)
  end

  def show
  end

  def new
    @comment = Comment.new
  end

  def create
    @comment = Comment.new(normalized_comment_params)

    if @comment.save
      redirect_to admin_activity_comment_path(@comment), notice: "活動コメントを登録しました。"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @comment.update(normalized_comment_params)
      redirect_to admin_activity_comment_path(@comment), notice: "活動コメントを更新しました。"
    else
      render :edit
    end
  end

  def destroy
    @comment.destroy
    redirect_to admin_activity_comments_path, alert: "活動コメントを削除しました。"
  end

  private

  def set_comment
    @comment = Comment.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:customer_id, :activity_id, :comment, :stamp_type)
  end

  def normalized_comment_params
    attrs = comment_params.to_h
    attrs["stamp_type"] = nil if attrs["comment"].present?
    attrs
  end
end
