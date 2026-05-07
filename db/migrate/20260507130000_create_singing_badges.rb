class CreateSingingBadges < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_badges do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :singing_ranking_season, null: false, foreign_key: true,
                                            index: { name: "index_singing_badges_on_season_id" }
      t.string :badge_type, null: false
      t.datetime :awarded_at, null: false

      t.timestamps
    end

    add_index :singing_badges,
              [:customer_id, :singing_ranking_season_id, :badge_type],
              unique: true,
              name: "index_singing_badges_unique"
  end
end
