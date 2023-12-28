class JoinPartCustomer < ApplicationRecord
  belongs_to :customer
  belongs_to :join_part
end
