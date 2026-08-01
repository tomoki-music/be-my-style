class CommunityOwner < ApplicationRecord
  belongs_to :customer
  belongs_to :community

  validates :customer_id, uniqueness: { scope: :community_id }
end
