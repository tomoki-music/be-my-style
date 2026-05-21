class AddResolvedToSingingRecapMovieBatchFailures < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_recap_movie_batch_failures, :resolved_at, :datetime
    add_column :singing_recap_movie_batch_failures, :resolved_movie_id, :bigint

    add_index :singing_recap_movie_batch_failures, :resolved_movie_id,
              name: "idx_batch_failures_on_resolved_movie"
    add_foreign_key :singing_recap_movie_batch_failures,
                    :singing_generated_recap_movies,
                    column: :resolved_movie_id
  end
end
