class Comment < ApplicationRecord
  belongs_to :customer
  belongs_to :activity

  validates :comment, presence: true
end
