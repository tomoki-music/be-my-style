module Business
  module Memberships
    # コミュニティの参加資格を外す(本人の退会 / 運営者のアクセス停止)。
    # 配下プロジェクトの参加済み・承認待ちも同時に消し、プロジェクト・スレッドへも即座にアクセスできなくする。
    # suspend: true のときはアクセス停止を記録し、自動承認でも再参加できないようにする。
    class RevokeCommunityAccess
      def self.call(community:, customer:, suspend: false, actor: nil)
        new(community, customer, suspend, actor).call
      end

      def initialize(community, customer, suspend, actor)
        @community = community
        @customer = customer
        @suspend = suspend
        @actor = actor
      end

      def call
        @community.with_lock do
          CommunityCustomer.where(community_id: @community.id, customer_id: @customer.id).destroy_all
          Permit.where(community_id: @community.id, customer_id: @customer.id).destroy_all
          ProjectRows.clear!(community: @community, customer: @customer)

          if @suspend && !@customer.business_community_suspended?(@community)
            CommunityAccessSuspension.create!(community: @community, customer: @customer, suspended_by: @actor)
          end
        end
        true
      end
    end
  end
end
