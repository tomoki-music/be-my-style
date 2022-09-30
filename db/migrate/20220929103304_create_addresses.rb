class CreateAddresses < ActiveRecord::Migration[6.1]
  def change
    create_table :addresses do |t|
      t.references :customer, null: false, foreign_key: true
      t.integer :postal_code
      t.string :address
      t.string :address_name
      t.string :tell

      t.timestamps
    end
  end
end
