class CreateOrders < ActiveRecord::Migration[6.1]
  def change
    create_table :orders do |t|
      t.references :customer, null: false, foreign_key: true
      t.integer :postal_code, null: false
      t.string :address, null: false
      t.string :address_name, null: false
      t.string :tell, null: false
      t.integer :postage, null: false
      t.integer :billing, null: false
      t.integer :payment, null: false, default:0
      t.integer :status, null: false, default:0

      t.timestamps
    end
  end
end
