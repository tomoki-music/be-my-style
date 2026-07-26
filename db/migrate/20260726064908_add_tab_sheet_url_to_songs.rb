class AddTabSheetUrlToSongs < ActiveRecord::Migration[6.1]
  def change
    add_column :songs, :tab_sheet_url, :string, limit: 2048
  end
end
