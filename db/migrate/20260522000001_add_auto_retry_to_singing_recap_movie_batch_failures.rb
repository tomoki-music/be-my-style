class AddAutoRetryToSingingRecapMovieBatchFailures < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_recap_movie_batch_failures, :auto_retry_status, :string,
               default: "not_applicable", null: false
    add_column :singing_recap_movie_batch_failures, :auto_retry_attempts_count, :integer,
               default: 0, null: false
    add_column :singing_recap_movie_batch_failures, :next_auto_retry_at, :datetime
    add_column :singing_recap_movie_batch_failures, :last_auto_retry_at, :datetime
    add_column :singing_recap_movie_batch_failures, :auto_retry_error_message, :string, limit: 1000

    add_index :singing_recap_movie_batch_failures, :auto_retry_status
    add_index :singing_recap_movie_batch_failures, :next_auto_retry_at
  end
end
