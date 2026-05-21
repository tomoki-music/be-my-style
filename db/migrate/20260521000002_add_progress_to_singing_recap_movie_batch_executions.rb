class AddProgressToSingingRecapMovieBatchExecutions < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_recap_movie_batch_executions, :total_movies_count,     :integer, null: false, default: 0
    add_column :singing_recap_movie_batch_executions, :completed_movies_count,  :integer, null: false, default: 0
    add_column :singing_recap_movie_batch_executions, :failed_movies_count,     :integer, null: false, default: 0
    add_column :singing_recap_movie_batch_executions, :started_at,              :datetime
    add_column :singing_recap_movie_batch_executions, :finished_at,             :datetime
  end
end
