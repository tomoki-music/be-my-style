class CreateOrderItems < ActiveRecord::Migration[6.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      t.integer :order_price, null: false
      t.integer :order_quantity, null: false
      t.integer :status, null: false, default:0

      t.timestamps
    end
  end
end
