class Customer < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum part: {
    vocal: 0,
    guitar: 1,
    bass: 2,
    drums: 3,
    keybord: 4,
    composer: 5,
    percussion: 6,
    wind_instrument: 7,
    stringed_instrument: 8,
    disc_jocke: 9,
    dancer: 10,
    others: 11,
  }, _prefix: true

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
