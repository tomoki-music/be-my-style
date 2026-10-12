class Business::HomesController < ApplicationController
  skip_before_action :authenticate_customer!, only: [:top]

  TOP_PROJECT_LIMIT = 6

  # プロジェクトの一覧・詳細はログイン中の会員だけが閲覧できる(Business::ProjectsController)。
  # 未ログインのトップではプロジェクトの名前・件数を含め何も取得しない。
  def top
    return unless customer_signed_in?

    @top_projects = Project.in_domain(@current_domain)
      .includes(:community, project_image_attachment: :blob)
      .recently_updated
      .limit(TOP_PROJECT_LIMIT)
      .to_a
    project_ids = @top_projects.map(&:id)
    @joined_project_ids = current_customer.project_members.where(project_id: project_ids).pluck(:project_id).to_set
    @joined_community_ids = current_customer.community_customers.where(community_id: @top_projects.map(&:community_id)).pluck(:community_id).to_set
  end
end
