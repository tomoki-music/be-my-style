class Request < ApplicationRecord
  belongs_to :customer
  belongs_to :event

  validates :request, presence: true
end
