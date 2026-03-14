class CommunityPost < ApplicationRecord
  belongs_to :customer
  belongs_to :community

  validates :body, presence: true
end
