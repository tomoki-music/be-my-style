class JoinPartCustomer < ApplicationRecord
  belongs_to :customer
  belongs_to :join_part

  scope :with_session_credit, -> { where(session_credit_applied: true) }
end
