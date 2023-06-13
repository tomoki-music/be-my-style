class Community < ApplicationRecord
  has_many :community_customers, dependent: :destroy
  has_many :customers, through: :community_customers, dependent: :destroy

  has_one_attached :community_image

  validates :name, presence: true
  validates :introduction, presence: true
end
