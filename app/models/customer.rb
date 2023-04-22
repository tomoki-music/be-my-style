class Customer < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  extend ActiveHash::Associations::ActiveRecordExtensions
  belongs_to :prefecture

  enum sex: {
    gender_private: 0,
    male: 1,
    female: 2,
    others: 3,
  }, _prefix: true

  has_one_attached :profile_image
  has_many :addresses, dependent: :destroy
  has_many :carts, dependent: :destroy
  has_many :customer_parts, dependent: :destroy
  has_many :parts, through: :customer_parts

  validates :name, presence: true, length: {maximum: 20}
end
