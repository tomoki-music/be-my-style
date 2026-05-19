class AddShareTrackingToSingingGeneratedRecapMovies < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_generated_recap_movies, :share_count,                  :integer,  null: false, default: 0
    add_column :singing_generated_recap_movies, :download_count,               :integer,  null: false, default: 0
    add_column :singing_generated_recap_movies, :instagram_hint_click_count,   :integer,  null: false, default: 0
    add_column :singing_generated_recap_movies, :first_shared_at,              :datetime
    add_column :singing_generated_recap_movies, :last_shared_at,               :datetime
    add_column :singing_generated_recap_movies, :last_downloaded_at,           :datetime
    add_column :singing_generated_recap_movies, :last_instagram_hint_clicked_at, :datetime
  end
end
