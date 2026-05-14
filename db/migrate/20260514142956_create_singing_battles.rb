class CreateSingingBattles < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_battles do |t|
      t.string :token, null: false
      t.string :song_title
      t.string :performance_type
      t.integer :status, null: false, default: 0
      t.datetime :expires_at, null: false
      t.bigint :challenger_id, null: false
      t.bigint :opponent_id
      t.bigint :challenger_diagnosis_id, null: false
      t.bigint :opponent_diagnosis_id

      t.timestamps
    end

    add_index :singing_battles, :token, unique: true
    add_index :singing_battles, :challenger_id
    add_index :singing_battles, :opponent_id
    add_index :singing_battles, :challenger_diagnosis_id
    add_foreign_key :singing_battles, :customers, column: :challenger_id, name: "fk_singing_battles_challenger"
    add_foreign_key :singing_battles, :customers, column: :opponent_id, name: "fk_singing_battles_opponent"
    add_foreign_key :singing_battles, :singing_diagnoses, column: :challenger_diagnosis_id, name: "fk_singing_battles_challenger_diagnosis"
    add_foreign_key :singing_battles, :singing_diagnoses, column: :opponent_diagnosis_id, name: "fk_singing_battles_opponent_diagnosis"
  end
end
