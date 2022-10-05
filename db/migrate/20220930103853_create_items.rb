class CreateItems < ActiveRecord::Migration[6.1]
  def change
    create_table :items do |t|
      t.string :name, null: false
      t.text :body, null: false
      t.integer :price, null: false
      t.boolean :status, default: true, null: false
      t.integer :stock, null: false

      t.timestamps
    end
  end
end
