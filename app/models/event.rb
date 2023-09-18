class Event < ApplicationRecord
  has_many :songs, dependent: :destroy
  belongs_to :customer
  belongs_to :community

  accepts_nested_attributes_for :songs, allow_destroy: true
end
