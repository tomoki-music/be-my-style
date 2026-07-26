class AddChordSheetInfoToSongs < ActiveRecord::Migration[6.1]
  def change
    add_column :songs, :chord_sheet_url, :string, limit: 2048
    add_column :songs, :musical_key, :string, limit: 100
    add_column :songs, :capo, :integer
    add_column :songs, :chord_sheet_note, :text
  end
end
