class CreateCustomerParts < ActiveRecord::Migration[6.1]
  def change
    create_table :customer_parts do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :part, null: false, foreign_key: true

      t.timestamps
    end
  end
end
