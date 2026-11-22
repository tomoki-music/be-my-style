module Business
  # Business コミュニティの一覧の取得。絞り込み・並び順・ページ分割はすべてここ(SQL)で行い、
  # 表示中のページ分だけ参加状況(Business::Memberships::CommunityStatuses)を求める。
  #
  #   browsable: ホーム(/business)。公開・閲覧条件の範囲(Business ドメインのコミュニティ全件)で、参加済み・未参加を問わない。
  #   joined:    コミュニティ一覧(/business/communities)。参加済み(community_customers の行がある)だけ。
  #              承認待ち(permits)は参加済みではないため含めない。
  class CommunityDirectory
    Result = Struct.new(:communities, :statuses, keyword_init: true)

    def self.browsable(customer, page:, per:)
      new(customer).fetch(business_communities, page: page, per: per)
    end

    def self.joined(customer, page:, per:)
      new(customer).fetch(business_communities.where(id: customer.community_customers.select(:community_id)), page: page, per: per)
    end

    def self.business_communities
      Community.where(domain_id: Domain.where(name: "business").select(:id))
    end
    private_class_method :business_communities

    def initialize(customer)
      @customer = customer
    end

    def fetch(scope, page:, per:)
      communities = scope
        .with_attached_community_image
        .order(updated_at: :desc, id: :desc)
        .page(page).per(per)
      Result.new(
        communities: communities,
        statuses: Business::Memberships::CommunityStatuses.call(customer: @customer, communities: communities)
      )
    end
  end
end
