class AddShareEnabledToSingingGeneratedRecapMovies < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_generated_recap_movies, :share_enabled, :boolean, default: true, null: false
  end
end
