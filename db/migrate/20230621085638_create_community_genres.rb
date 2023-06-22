class CreateCommunityGenres < ActiveRecord::Migration[6.1]
  def change
    create_table :community_genres do |t|
      t.references :community, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true

      t.timestamps
    end
  end
end
