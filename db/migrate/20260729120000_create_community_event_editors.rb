class CreateCommunityEventEditors < ActiveRecord::Migration[6.1]
  def change
    create_table :community_event_editors do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :community, null: false, foreign_key: true

      t.timestamps
    end

    add_index :community_event_editors, [:community_id, :customer_id], unique: true, name: "index_community_event_editors_on_community_id_and_customer_id"
  end
end
