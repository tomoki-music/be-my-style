class AddPositionToSongsAndSetInitialValues < ActiveRecord::Migration[6.1]
  def up
    add_column :songs, :position, :integer

    # 既存イベントの曲に順番をセット
    Event.find_each do |event|
      event.songs.order(:created_at).each.with_index(1) do |song, index|
        song.update_column(:position, index)
      end
    end
  end

  def down
    remove_column :songs, :position
  end
end
