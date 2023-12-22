class Song < ApplicationRecord
  belongs_to :event
  has_many :song_customers, dependent: :destroy
  has_many :customers, through: :song_customers, dependent: :destroy
  has_many :join_parts, dependent: :destroy

  accepts_nested_attributes_for :join_parts, allow_destroy: true, reject_if: :all_blank

  with_options presence: true do
    validates :song_name
  end
end
