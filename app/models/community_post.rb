class CommunityPost < ApplicationRecord
  include BusinessChatContent

  belongs_to :customer
  belongs_to :community
end
