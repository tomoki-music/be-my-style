class Song < ApplicationRecord
  belongs_to :event
  has_many :song_customers, dependent: :destroy
  has_many :customers, through: :song_customers, dependent: :destroy

  with_options presence: true do
    validates :song_name
  end
end
