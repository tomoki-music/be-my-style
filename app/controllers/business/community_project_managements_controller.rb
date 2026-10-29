# コミュニティの「プロジェクト管理」画面。新しいプロジェクトの作成導線と、このコミュニティのプロジェクト一覧を置く。
# 開けるのはプロジェクトを作成できる人(Customer#can_create_project_for?)だけで、作成画面・作成処理と同じ判定にする。
class Business::CommunityProjectManagementsController < ApplicationController
  include BusinessAccessControl

  before_action :set_community
  before_action :authorize_project_creation!

  def show
    @projects = @community.projects.includes(:customer).recently_updated.to_a
    @can_manage_community = current_customer.can_manage_community?(@community)
    @manageable_project_ids = @projects.select { |project| @can_manage_community || project.customer_id == current_customer.id }.map(&:id).to_set
    load_pending_permit_count if @can_manage_community
  end

  private

  def set_community
    @community = find_business_community!(params[:community_id])
  end

  def authorize_project_creation!
    return if current_customer.can_create_project_for?(@community)

    redirect_to business_community_path(@community), alert: "このコミュニティでプロジェクトを作成する権限がありません。"
  end

  def load_pending_permit_count
    @pending_permit_count = @community.permits.joins(:customer).merge(Customer.active).count
  end
end
