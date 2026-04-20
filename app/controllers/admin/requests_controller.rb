class Admin::RequestsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_request, only: [:show, :edit, :update, :destroy]

  def index
    @requests = Request.includes(:customer, :event).order(created_at: :desc)
  end

  def show
  end

  def new
    @request = Request.new
  end

  def create
    @request = Request.new(request_params)

    if @request.save
      redirect_to admin_request_path(@request), notice: "イベントコメントを登録しました。"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @request.update(request_params)
      redirect_to admin_request_path(@request), notice: "イベントコメントを更新しました。"
    else
      render :edit
    end
  end

  def destroy
    @request.destroy
    redirect_to admin_requests_path, alert: "イベントコメントを削除しました。"
  end

  private

  def set_request
    @request = Request.find(params[:id])
  end

  def request_params
    params.require(:request).permit(:customer_id, :event_id, :request, :stamp_type)
  end
end
