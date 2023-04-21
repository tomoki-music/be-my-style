class CustomerPart < ApplicationRecord
  belongs_to :customer
  belongs_to :part
end
