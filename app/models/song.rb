class Song < ApplicationRecord
  belongs_to :event

  with_options presence: true do
    validates :song_name
  end
end
