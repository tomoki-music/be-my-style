class CreateSingingDiagnoses < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_diagnoses do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :song_title
      t.text :memo
      t.integer :status, null: false, default: 0
      t.integer :overall_score
      t.integer :pitch_score
      t.integer :rhythm_score
      t.integer :expression_score
      t.text :result_payload
      t.datetime :diagnosed_at

      t.timestamps
    end

    add_index :singing_diagnoses, :status
    add_index :singing_diagnoses, :diagnosed_at
  end
end
