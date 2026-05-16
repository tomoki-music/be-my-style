class AddPinnedAtToSingingAchievementBadges < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_achievement_badges, :pinned_at, :datetime
    add_index  :singing_achievement_badges, [:customer_id, :pinned_at],
               name: "index_singing_achievement_badges_on_customer_pinned"
  end
end
