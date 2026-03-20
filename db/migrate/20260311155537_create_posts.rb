class CreatePosts < ActiveRecord::Migration[6.1]
  def change
    create_table :posts do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :title
      t.text :body
      t.integer :category

      t.timestamps
    end
    add_index :likes, [:customer_id, :post_id], unique: true
  end
end
