class CreateSongTemplates < ActiveRecord::Migration[6.1]
  def change
    create_table :song_templates do |t|
      t.references :community, null: false, foreign_key: true
      t.references :customer, null: true, foreign_key: true
      t.references :source_song, null: true, foreign_key: { to_table: :songs }

      t.string :song_name, null: false
      t.string :artist_name
      t.string :youtube_url
      t.text :introduction
      t.string :chord_sheet_url, limit: 2048
      t.string :tab_sheet_url, limit: 2048
      t.string :musical_key, limit: 100
      t.integer :capo
      t.text :chord_sheet_note

      t.timestamps
    end
  end
end
