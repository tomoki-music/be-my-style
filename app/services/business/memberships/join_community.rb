module Business
  module Memberships
    # 会員が「参加する / 参加を申請する」を押したときの処理。
    # 自動承認なら即参加、手動承認なら承認待ち(Permit)を作る。ページを見ただけでは呼ばない。
    #
    # 戻り値: :joined / :requested / :already_member / :already_requested / :suspended / :business_required / :unavailable
    class JoinCommunity
      def self.call(community:, customer:)
        new(community, customer).call
      end

      def initialize(community, customer)
        @community = community
        @customer = customer
      end

      def call
        return :unavailable if @customer.is_deleted? || !@community.business_domain?
        return :business_required unless @customer.business_eligible?

        # 同じコミュニティへの申請・参加を直列化し、連打・同時リクエストでも行を重複させない。
        @community.with_lock do
          next :suspended if @customer.business_community_suspended?(@community)
          next :already_member if @customer.business_community_member?(@community)

          # 手動承認だった頃の承認待ちは、方式を自動へ変えても承認待ちのまま(本人が取り消せば参加し直せる)。
          next :already_requested if @customer.business_community_pending?(@community)

          if @community.join_auto?
            ProjectRows.clear!(community: @community, customer: @customer)
            CommunityCustomer.create!(community: @community, customer: @customer)
            :joined
          else
            Permit.create!(community: @community, customer: @customer)
            :requested
          end
        end
      end
    end
  end
end
