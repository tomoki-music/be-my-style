module Business
  module Memberships
    # 閲覧者から見た各コミュニティの参加状況。一覧(複数件)と詳細(1件)で同じ判定・同じ表示にするため、
    # 表示中のコミュニティ分だけを種類ごとに1回ずつ問い合わせて決める。
    #
    #   :operator  運営(オーナー / 運営権限。can_manage_community? のうち admin 以外)
    #   :admin     管理権限あり(システム管理者。参加申請なしで閲覧・管理できる)
    #   :member    参加中
    #   :suspended アクセス停止中(再参加・再申請できない)
    #   :pending   承認待ち
    #   :none      未参加(参加する / 参加を申請する)
    class CommunityStatuses
      def self.call(customer:, communities:)
        new(customer, communities).call
      end

      def self.for(customer:, community:)
        call(customer: customer, communities: [community]).fetch(community.id)
      end

      def initialize(customer, communities)
        @customer = customer
        @ids = communities.map(&:id)
      end

      def call
        return {} if @ids.empty?

        operated = @customer.manageable_communities.where(id: @ids).pluck(:id).to_set
        joined = ids_in(@customer.community_customers)
        suspended = ids_in(@customer.community_access_suspensions)
        pending = ids_in(@customer.permits)

        @ids.index_with do |id|
          if operated.include?(id) then :operator
          elsif @customer.admin? then :admin
          elsif joined.include?(id) then :member
          elsif suspended.include?(id) then :suspended
          elsif pending.include?(id) then :pending
          else :none
          end
        end
      end

      private

      def ids_in(relation)
        relation.where(community_id: @ids).pluck(:community_id).to_set
      end
    end
  end
end
