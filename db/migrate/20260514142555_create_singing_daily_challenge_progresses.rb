class CreateSingingDailyChallengeProgresses < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_daily_challenge_progresses do |t|
      t.references :customer, null: false, foreign_key: true, index: false
      t.bigint :singing_daily_challenge_id, null: false
      t.datetime :completed_at
      t.integer :xp_rewarded, default: 0, null: false

      t.timestamps
    end

    add_foreign_key :singing_daily_challenge_progresses, :singing_daily_challenges,
                    name: "fk_sdcp_on_singing_daily_challenge"
    add_index :singing_daily_challenge_progresses,
              [:customer_id, :singing_daily_challenge_id],
              unique: true,
              name: "idx_sdcp_customer_challenge"
  end
end
