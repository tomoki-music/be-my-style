class CreateEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :events do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :community, null: false, foreign_key: true
      t.string :event_name, null: false
      t.datetime :event_date, null: false
      t.integer :entrance_fee, null: false
      t.text :introduction
      t.string :address, null: false
      t.float :latitude
      t.float :longitude
      t.timestamps
    end
  end
end
