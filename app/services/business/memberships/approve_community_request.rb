module Business
  module Memberships
    # 運営者による承認待ち申請(Permit)の承認。権限の確認は呼び出し側(コントローラ)で行う。
    #
    # 戻り値: :approved / :not_found / :withdrawn / :suspended
    class ApproveCommunityRequest
      def self.call(community:, customer_id:)
        new(community, customer_id).call
      end

      def initialize(community, customer_id)
        @community = community
        @customer_id = customer_id
      end

      def call
        @community.with_lock do
          permit = @community.permits.includes(:customer).find_by(customer_id: @customer_id)
          next :not_found unless permit

          customer = permit.customer
          next :withdrawn if customer.is_deleted?

          if customer.business_community_suspended?(@community)
            permit.destroy!
            next :suspended
          end

          unless customer.business_community_member?(@community)
            ProjectRows.clear!(community: @community, customer: customer)
            CommunityCustomer.create!(community: @community, customer: customer)
          end
          permit.destroy!
          :approved
        end
      end
    end
  end
end
