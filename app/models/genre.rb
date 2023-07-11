class Genre < ApplicationRecord
  has_many :customer_genres, dependent: :destroy
  has_many :customers, through: :customer_genres, dependent: :destroy
  has_many :community_genres, dependent: :destroy
  has_many :communities, through: :community_genres, dependent: :destroy
end
