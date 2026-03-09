class Domain < ApplicationRecord
  has_many :customer_domains
  has_many :customers, through: :customer_domains
end
