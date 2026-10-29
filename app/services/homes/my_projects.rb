module Homes
  # ログイン後ホームの「プロジェクト」一覧(Business のみ)。条件は BusinessAccess と揃え、
  # プロジェクト詳細(business_community_participant? が前提)へ進めるものだけを出す。
  #
  #   運営しているコミュニティのプロジェクト                     : 管理
  #   参加中のコミュニティで、自分が作成したプロジェクト          : 主催
  #   参加中のコミュニティで、承認済みの参加者になっているもの    : 参加中
  #   参加中のコミュニティで、参加申請が承認待ちのもの            : 承認待ち(詳細では概要のみ表示される)
  #
  # 親コミュニティから退出・アクセス停止になると、運営者でない限りどの条件にも当たらなくなる。
  # 管理者(admin?)の全件閲覧権限はホームには持ち込まない(MyCommunities と同じ)。
  class MyProjects
    PER_PAGE = 6

    Result = Struct.new(:projects, :statuses, keyword_init: true)

    # with_images: Business ホームのように画像を表示する画面だけ、画像の添付をまとめて読み込む。
    def self.call(customer, page: nil, with_images: false)
      new(customer).call(page: page, with_images: with_images)
    end

    def initialize(customer)
      @customer = customer
    end

    def call(page: nil, with_images: false)
      projects = scope.includes(:community).recently_updated.page(page).per(PER_PAGE)
      projects = projects.includes(project_image_attachment: :blob) if with_images
      Result.new(projects: projects, statuses: statuses_for(projects.to_a))
    end

    private

    def scope
      domain = Domain.find_by(name: "business")
      return Project.none if domain.nil?

      base = Project.in_domain(domain)
      member_community_ids = @customer.community_customers.select(:community_id)

      base.where(community_id: @customer.manageable_communities.select(:id))
        .or(base.where(community_id: member_community_ids, customer_id: @customer.id))
        .or(base.where(community_id: member_community_ids, id: @customer.project_members.select(:project_id)))
        .or(base.where(community_id: member_community_ids, id: @customer.project_join_requests.select(:project_id)))
    end

    def statuses_for(projects)
      return {} if projects.empty?

      managed = @customer.manageable_communities.where(id: projects.map(&:community_id)).pluck(:id).to_set
      joined = @customer.project_members.where(project_id: projects.map(&:id)).pluck(:project_id).to_set

      projects.to_h do |project|
        status =
          if @customer.admin? || managed.include?(project.community_id) then :manager
          elsif project.customer_id == @customer.id then :owner
          elsif joined.include?(project.id) then :member
          else :pending
          end
        [project.id, status]
      end
    end
  end
end
