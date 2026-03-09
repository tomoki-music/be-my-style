class CustomerDomain < ApplicationRecord
  belongs_to :customer
  belongs_to :domain
end
