class CreateJoinPartCustomers < ActiveRecord::Migration[6.1]
  def change
    create_table :join_part_customers do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :join_part, null: false, foreign_key: true
      t.timestamps
    end
  end
end
