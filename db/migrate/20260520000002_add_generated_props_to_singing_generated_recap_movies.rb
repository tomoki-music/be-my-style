class AddGeneratedPropsToSingingGeneratedRecapMovies < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_generated_recap_movies, :generated_props, :json
  end
end
