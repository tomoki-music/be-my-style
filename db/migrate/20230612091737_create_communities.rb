class CreateCommunities < ActiveRecord::Migration[6.1]
  def change
    create_table :communities do |t|
      t.string :name
      t.text :introduction
      t.integer :owner_id
      t.integer :activity_stance
      t.text :favorite_artist1
      t.text :favorite_artist2
      t.text :favorite_artist3
      t.text :favorite_artist4
      t.text :favorite_artist5
      t.text :url
      t.integer :prefecture_id
      t.timestamps
    end
  end
end
