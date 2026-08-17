class JoinPart < ApplicationRecord
  belongs_to :song
  has_many :join_part_customers, dependent: :destroy
  has_many :customers, through: :join_part_customers, dependent: :destroy

  with_options presence: true do
    validates :join_part_name
  end

  # 一般・公開画面で「現役参加者」だけを扱う際に使う。
  # JoinPartCustomerレコード自体は削除しないため、ここでの絞り込みは表示専用。
  def active_customers
    customers.active
  end
end
