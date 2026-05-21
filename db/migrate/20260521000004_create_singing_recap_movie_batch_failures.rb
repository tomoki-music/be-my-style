class CreateSingingRecapMovieBatchFailures < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_recap_movie_batch_failures do |t|
      t.references :singing_recap_movie_batch_execution, null: false, foreign_key: true,
                   index: { name: "idx_batch_failures_on_execution_id" }
      t.references :customer, null: false, foreign_key: true
      t.integer    :year, null: false
      t.bigint     :recap_movie_id
      t.string     :error_class, null: false
      t.string     :error_message, limit: 1000
      t.text       :backtrace_excerpt
      t.datetime   :failed_at, null: false
      t.json       :metadata

      t.timestamps
    end

    add_index :singing_recap_movie_batch_failures, [:singing_recap_movie_batch_execution_id, :customer_id],
              name: "idx_batch_failures_on_execution_and_customer"
  end
end
