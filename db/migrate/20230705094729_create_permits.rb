class CreatePermits < ActiveRecord::Migration[6.1]
  def change
    create_table :permits do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :community, null: false, foreign_key: true

      t.timestamps
    end
  end
end
