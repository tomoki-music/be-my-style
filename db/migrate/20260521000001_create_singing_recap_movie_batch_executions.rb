class CreateSingingRecapMovieBatchExecutions < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_recap_movie_batch_executions do |t|
      t.integer  :year,                    null: false
      t.bigint   :admin_id,                null: true
      t.integer  :target_customers_count,  null: false, default: 0
      t.integer  :new_movies_count,        null: false, default: 0
      t.integer  :regenerate_movies_count, null: false, default: 0
      t.integer  :skipped_movies_count,    null: false, default: 0
      t.json     :skipped_breakdown
      t.string   :status,                  null: false, default: "enqueued"
      t.datetime :enqueued_at

      t.timestamps
    end

    add_index :singing_recap_movie_batch_executions, :year
    add_index :singing_recap_movie_batch_executions, :admin_id
    add_foreign_key :singing_recap_movie_batch_executions, :admins
  end
end
