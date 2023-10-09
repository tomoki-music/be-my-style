class Event < ApplicationRecord
  has_one_attached :event_image
  has_many :songs, dependent: :destroy
  belongs_to :customer
  belongs_to :community

  accepts_nested_attributes_for :songs, allow_destroy: true, reject_if: :all_blank

  geocoded_by :address
  after_validation :geocode, if: :address_changed?

  with_options presence: true do
    validates :event_name
    validates :event_start_time
    validates :event_end_time
    validates :entrance_fee
    validates :address
    validates :songs
  end

end
