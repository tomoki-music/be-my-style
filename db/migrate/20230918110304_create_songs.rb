class CreateSongs < ActiveRecord::Migration[6.1]
  def change
    create_table :songs do |t|
      t.references :event, null: false, foreign_key: true
      t.string :song_name, null: false
      t.string :youtube_url
      t.text :introduction
      t.timestamps
    end
  end
end
