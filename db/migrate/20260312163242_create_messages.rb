class CreateMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :messages do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.text :body

      t.timestamps
    end
  end
end
