class AddRetryToSingingRecapMovieBatchFailures < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_recap_movie_batch_failures, :retry_status,        :string,   default: "pending", null: false
    add_column :singing_recap_movie_batch_failures, :retried_at,          :datetime
    add_column :singing_recap_movie_batch_failures, :retried_by_id,       :bigint
    add_column :singing_recap_movie_batch_failures, :retry_error_message, :string,   limit: 1000

    add_index :singing_recap_movie_batch_failures, :retried_by_id,
              name: "idx_batch_failures_on_retried_by"
    add_index :singing_recap_movie_batch_failures, :retry_status,
              name: "idx_batch_failures_on_retry_status"

    add_foreign_key :singing_recap_movie_batch_failures, :admins,
                    column: :retried_by_id
  end
end
