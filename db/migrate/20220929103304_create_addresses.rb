class CreateAddresses < ActiveRecord::Migration[6.1]
  def change
    create_table :addresses do |t|
      t.references :customer, null: false, foreign_key: true
      t.integer :postal_code, null: false
      t.string :address, null: false
      t.string :address_name, null: false
      t.string :tell

      t.timestamps
    end
  end
end
