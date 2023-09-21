class Event < ApplicationRecord
  has_many :songs, dependent: :destroy
  belongs_to :customer
  belongs_to :community

  accepts_nested_attributes_for :songs, allow_destroy: true

  with_options presence: true do
    validates :event_name
    validates :event_date
    validates :entrance_fee
    validates :introduction
    validates :address
    validates :songs
  end
end
