class AddResultSummaryToSingingRecapMovieBatchExecutions < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_recap_movie_batch_executions, :actual_created_movies_count,     :integer, null: false, default: 0
    add_column :singing_recap_movie_batch_executions, :actual_regenerated_movies_count,  :integer, null: false, default: 0
    add_column :singing_recap_movie_batch_executions, :actual_skipped_movies_count,      :integer, null: false, default: 0
  end
end
