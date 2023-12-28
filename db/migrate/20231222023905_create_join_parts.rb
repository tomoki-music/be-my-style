class CreateJoinParts < ActiveRecord::Migration[6.1]
  def change
    create_table :join_parts do |t|
      t.references :song, null: false, foreign_key: true
      t.string :join_part_name, null: false
      t.timestamps
    end
  end
end
