class Part < ApplicationRecord
  has_many :customer_parts, dependent: :destroy
  has_many :customers, through: :customer_parts, dependent: :destroy
end
