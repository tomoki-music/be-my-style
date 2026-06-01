class CreateSingingCheerReactions < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_cheer_reactions do |t|
      t.references :customer,        null: false, foreign_key: true
      t.references :target_customer, null: false, foreign_key: { to_table: :customers }
      t.string :reaction_type, null: false, limit: 40

      t.timestamps
    end

    add_index :singing_cheer_reactions,
              [:customer_id, :target_customer_id, :reaction_type],
              unique: true,
              name: "index_singing_cheer_reactions_unique"

    add_index :singing_cheer_reactions,
              [:target_customer_id, :reaction_type],
              name: "index_singing_cheer_reactions_on_target_and_type"
  end
end
