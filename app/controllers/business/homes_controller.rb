class Business::HomesController < ApplicationController
  skip_before_action :authenticate_customer!, only: [:top]

  TOP_PROJECT_LIMIT = 6

  # 一覧と同じく、内部を閲覧できるコミュニティ(参加済み・運営中)のプロジェクトだけを出す。
  # 未ログインのトップではプロジェクトの名前・件数を含め何も取得しない。
  def top
    return unless customer_signed_in?

    @top_projects = current_customer.business_visible_projects(@current_domain)
      .includes(:community, project_image_attachment: :blob)
      .recently_updated
      .limit(TOP_PROJECT_LIMIT)
      .to_a
    project_ids = @top_projects.map(&:id)
    @joined_project_ids = current_customer.project_members.where(project_id: project_ids).pluck(:project_id).to_set
    @joined_community_ids = current_customer.community_customers.where(community_id: @top_projects.map(&:community_id)).pluck(:community_id).to_set
    @pending_project_ids = current_customer.project_join_requests.where(project_id: project_ids).pluck(:project_id).to_set
  end
end
