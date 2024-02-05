class CreateRequests < ActiveRecord::Migration[6.1]
  def change
    create_table :requests do |t|
      t.string :request
      t.references :customer, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.timestamps
    end
  end
end
