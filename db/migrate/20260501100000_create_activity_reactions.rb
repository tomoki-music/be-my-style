class CreateActivityReactions < ActiveRecord::Migration[6.1]
  def change
    create_table :activity_reactions do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :activity, null: false, foreign_key: true
      t.string :reaction_type, null: false

      t.timestamps
    end

    add_index :activity_reactions, [:customer_id, :activity_id, :reaction_type], unique: true, name: "index_activity_reactions_unique"
  end
end
