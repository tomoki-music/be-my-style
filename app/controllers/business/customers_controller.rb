class Business::CustomersController < ApplicationController
  layout "business"

  before_action :set_customer
  before_action :ensure_correct_customer, only: [:edit, :update]
  before_action :reject_deleted_customer, only: [:show]

  # 参加コミュニティは Business のものだけを出す(音楽コミュニティの名称・リンクは Business の画面に出さない)。
  def show
    @business_communities = @customer.communities.joins(:domain).where(domains: { name: "business" }).order(:id)
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to business_customer_path(@customer), notice: "更新しました"
    else
      render :edit
    end
  rescue ActiveRecord::RecordInvalid
    render :edit
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def ensure_correct_customer
    unless @customer == current_customer
      redirect_to business_root_path, alert: "権限がありません"
    end
  end

  def reject_deleted_customer
    return unless @customer.is_deleted

    redirect_to business_root_path, alert: "このユーザーのプロフィールは表示できません。"
  end

  # 音楽専用の項目(パート・ジャンル)は受け付けない。Business 側の保存で音楽のデータを変えないため。
  def customer_params
    params.require(:customer).permit(
      :name,
      :introduction,
      :profile_image,
      :job,
      :skills,
      :achievements,
      :url
    )
  end

end
