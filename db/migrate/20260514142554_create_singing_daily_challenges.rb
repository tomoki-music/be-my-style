class CreateSingingDailyChallenges < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_daily_challenges do |t|
      t.date :challenge_date, null: false
      t.string :challenge_type, null: false
      t.string :target_attribute, null: false
      t.integer :threshold_value, null: false
      t.integer :xp_reward, null: false, default: 30
      t.string :title, null: false
      t.text :description, null: false

      t.timestamps
    end

    add_index :singing_daily_challenges, :challenge_date, unique: true
  end
end
