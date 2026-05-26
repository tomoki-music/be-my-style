class CreateSingingRecapMovieStorageSnapshots < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_recap_movie_storage_snapshots do |t|
      t.date    :snapshot_date,           null: false
      t.integer :attached_movie_count,    null: false, default: 0
      t.bigint  :total_bytes,             null: false, default: 0
      t.bigint  :avg_bytes,               null: false, default: 0
      t.bigint  :completed_bytes,         null: false, default: 0
      t.bigint  :expired_attached_bytes,  null: false, default: 0
      t.bigint  :recent_bytes,            null: false, default: 0
      t.decimal :estimated_monthly_cost_usd, precision: 10, scale: 4, null: false, default: 0

      t.timestamps
    end

    add_index :singing_recap_movie_storage_snapshots, :snapshot_date, unique: true
  end
end
