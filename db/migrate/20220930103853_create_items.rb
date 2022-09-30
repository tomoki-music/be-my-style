class CreateItems < ActiveRecord::Migration[6.1]
  def change
    create_table :items do |t|
      t.string :name
      t.text :body
      t.integer :price
      t.boolean :status
      t.integer :stock

      t.timestamps
    end
  end
end
