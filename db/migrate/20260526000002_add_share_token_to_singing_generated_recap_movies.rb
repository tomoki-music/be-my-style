class AddShareTokenToSingingGeneratedRecapMovies < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_generated_recap_movies, :share_token, :string
    add_index  :singing_generated_recap_movies, :share_token, unique: true
  end
end
