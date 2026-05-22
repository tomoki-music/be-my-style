class AddCleanedUpAtToSingingGeneratedRecapMovies < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_generated_recap_movies, :cleaned_up_at, :datetime
    add_index  :singing_generated_recap_movies, :cleaned_up_at
  end
end
