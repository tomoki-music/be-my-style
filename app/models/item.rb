class Item < ApplicationRecord
    has_many :item_tags, dependent: :destroy
    has_many :tags, through: :item_tags
    has_many :carts, dependent: :destroy
end
