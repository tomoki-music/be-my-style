class CreateSongCustomers < ActiveRecord::Migration[6.1]
  def change
    create_table :song_customers do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :song, null: false, foreign_key: true

      t.timestamps
    end
  end
end
