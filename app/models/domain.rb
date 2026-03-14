class Domain < ApplicationRecord
  has_many :customer_domains
  has_many :customers, through: :customer_domains

  has_many :community_domains
  has_many :communities, through: :community_domains
end
