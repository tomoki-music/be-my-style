class AddArtistNameToSongs < ActiveRecord::Migration[6.1]
  def change
    add_column :songs, :artist_name, :string
  end
end
