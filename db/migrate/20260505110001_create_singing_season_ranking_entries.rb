class CreateSingingSeasonRankingEntries < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_season_ranking_entries do |t|
      t.references :singing_ranking_season, null: false, foreign_key: true,
                                            index: { name: "index_season_entries_on_season_id" }
      t.references :customer, null: false, foreign_key: true
      t.references :singing_diagnosis, null: true, foreign_key: true
      t.integer :rank, null: false
      t.integer :score, null: false
      t.string :category, null: false, default: "overall"
      t.string :title
      t.string :badge_key

      t.timestamps
    end

    add_index :singing_season_ranking_entries, :rank
    add_index :singing_season_ranking_entries, :category
    add_index :singing_season_ranking_entries,
              [:singing_ranking_season_id, :customer_id, :category],
              unique: true,
              name: "index_season_ranking_entries_unique"
  end
end
