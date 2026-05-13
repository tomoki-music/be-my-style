class CreateSingingAiChallengeProgresses < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_ai_challenge_progresses do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :target_key, null: false
      t.date :challenge_month, null: false
      t.boolean :tried, null: false, default: false
      t.boolean :completed, null: false, default: false
      t.boolean :next_diagnosis_planned, null: false, default: false
      t.datetime :completed_at
      t.json :metadata

      t.timestamps
    end

    add_index :singing_ai_challenge_progresses,
              [:customer_id, :challenge_month, :target_key],
              unique: true,
              name: "idx_singing_ai_progress_unique_month_target"
  end
end
