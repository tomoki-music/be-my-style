class AddPerformanceTimeToSongs < ActiveRecord::Migration[6.1]
  def change
    add_column :songs, :performance_time, :string
  end
end
