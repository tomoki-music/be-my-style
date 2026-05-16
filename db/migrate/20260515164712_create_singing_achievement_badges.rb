class CreateSingingAchievementBadges < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_achievement_badges do |t|
      t.references :customer, null: false, foreign_key: true
      t.string     :badge_key, null: false
      t.references :singing_diagnosis, null: true, foreign_key: true
      t.datetime   :earned_at, null: false
      t.json       :metadata
      t.timestamps precision: 6, null: false
    end

    add_index :singing_achievement_badges,
              [:customer_id, :badge_key],
              unique: true,
              name: "index_singing_achievement_badges_unique"

    add_index :singing_achievement_badges,
              [:customer_id, :earned_at],
              name: "index_singing_achievement_badges_on_customer_earned"
  end
end
