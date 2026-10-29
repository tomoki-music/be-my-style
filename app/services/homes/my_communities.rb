module Homes
  # ログイン後ホームの「コミュニティ」一覧。本人と明示的な関係(参加済み・運営・承認待ち)がある
  # コミュニティだけを、音楽 / Business をまたいで1回の問い合わせで取得する。
  #
  # 管理者(admin?)は全コミュニティを管理できるが、ホームは「自分の参加先」なので関係の無いものは出さない。
  # アクセス停止・退出はコミュニティ参加行と承認待ち行が消える(Business::Memberships)ため、ここでは除外条件を持たない。
  class MyCommunities
    PER_PAGE = 6

    Result = Struct.new(:communities, :statuses, keyword_init: true)

    def self.call(customer, page: nil)
      new(customer).call(page: page)
    end

    def initialize(customer)
      @customer = customer
    end

    def call(page: nil)
      communities = scope.includes(:domain).order(updated_at: :desc, id: :desc).page(page).per(PER_PAGE)
      Result.new(communities: communities, statuses: statuses_for(communities.map(&:id)))
    end

    private

    # 音楽コミュニティの画面は music ドメイン登録者に限られる(ApplicationController)。リンク先で
    # 弾かれるものは一覧にも出さない。
    def domain_names
      names = ["business"]
      names << "music" if @customer.admin? || @customer.music_user?
      names
    end

    def scope
      base = Community.where(domain_id: Domain.where(name: domain_names).select(:id))

      base.where(id: @customer.community_customers.select(:community_id))
        .or(base.where(owner_id: @customer.id))
        .or(base.where(id: @customer.community_owners.select(:community_id)))
        .or(base.where(id: @customer.permits.select(:community_id)))
    end

    # 表示中のページ分だけ、運営 > 参加中 > 承認待ち の順に状態を決める(can_manage_community? と同じ範囲)。
    def statuses_for(ids)
      return {} if ids.empty?

      managed = @customer.manageable_communities.where(id: ids).pluck(:id).to_set
      joined = @customer.community_customers.where(community_id: ids).pluck(:community_id).to_set

      ids.index_with do |id|
        if @customer.admin? || managed.include?(id) then :manager
        elsif joined.include?(id) then :member
        else :pending
        end
      end
    end
  end
end
