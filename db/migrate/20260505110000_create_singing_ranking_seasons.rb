class CreateSingingRankingSeasons < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_ranking_seasons do |t|
      t.string :name, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.string :status, null: false, default: "draft"
      t.string :season_type, null: false, default: "monthly"

      t.timestamps
    end

    add_index :singing_ranking_seasons, :status
    add_index :singing_ranking_seasons, :starts_on
    add_index :singing_ranking_seasons, :ends_on
  end
end
