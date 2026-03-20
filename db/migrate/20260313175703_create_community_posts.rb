class CreateCommunityPosts < ActiveRecord::Migration[6.1]
  def change
    create_table :community_posts do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :community, null: false, foreign_key: true
      t.text :body

      t.timestamps
    end
  end
end
