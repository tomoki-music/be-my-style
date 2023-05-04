class Genre < ApplicationRecord
  has_many :customer_genres, dependent: :destroy
  has_many :customers, through: :customer_genres
end
