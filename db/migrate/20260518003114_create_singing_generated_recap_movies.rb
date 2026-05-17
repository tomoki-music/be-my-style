class CreateSingingGeneratedRecapMovies < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_generated_recap_movies do |t|
      t.bigint   :customer_id, null: false
      t.integer  :year,        null: false
      t.string   :status,      null: false, default: "pending"
      t.json     :source_json
      t.text     :error_message
      t.datetime :generated_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :singing_generated_recap_movies, [:customer_id, :year], unique: true
    add_index :singing_generated_recap_movies, :status
    add_index :singing_generated_recap_movies, :expires_at
    add_foreign_key :singing_generated_recap_movies, :customers
  end
end
