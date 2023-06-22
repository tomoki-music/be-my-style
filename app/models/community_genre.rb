class CommunityGenre < ApplicationRecord
  belongs_to :community
  belongs_to :genre
end
