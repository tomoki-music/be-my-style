module MatchingIndex
  extend ActiveSupport::Concern
  
    def matching_index
      got_follow_customers_ids = Relationship.where(followed_id: current_customer.id).pluck(:follower_id)
      @mathing_customers = Relationship.where(followed_id: got_follow_customers_ids, follower_id: current_customer.id).where.not(followed_id: current_customer.id).map do |follow|
        follow.followed
      end
    end
  
  end

