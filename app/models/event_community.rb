class EventCommunity < ApplicationRecord
  belongs_to :event, inverse_of: :event_communities
  belongs_to :community

  validates :community_id, uniqueness: { scope: :event_id }
end
