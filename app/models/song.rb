class Song < ApplicationRecord
  belongs_to :event, inverse_of: :songs
  has_many :song_customers, dependent: :destroy
  has_many :customers, through: :song_customers, dependent: :destroy
  has_many :join_parts, dependent: :destroy

  accepts_nested_attributes_for :join_parts, allow_destroy: true, reject_if: :all_blank
  
  with_options presence: true do
    validates :song_name
  end

  before_validation :set_default_position, on: :create

  private
  
  def set_default_position
    self.position ||= (event.songs.maximum(:position) || 0) + 1 if event.present?
  end

end
