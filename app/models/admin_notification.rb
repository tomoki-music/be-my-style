class AdminNotification < ApplicationRecord
  default_scope -> { order(created_at: :desc) }

  belongs_to :admin
  belongs_to :customer

  validates :action, presence: true
  validates :plan, presence: true
end
