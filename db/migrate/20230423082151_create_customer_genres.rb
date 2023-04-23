class CreateCustomerGenres < ActiveRecord::Migration[6.1]
  def change
    create_table :customer_genres do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true

      t.timestamps
    end
  end
end
