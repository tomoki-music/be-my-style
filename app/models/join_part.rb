class JoinPart < ApplicationRecord
  belongs_to :song
  has_many :join_part_customers, dependent: :destroy
  has_many :customers, through: :join_part_customers, dependent: :destroy

  with_options presence: true do
    validates :join_part_name
  end
end
