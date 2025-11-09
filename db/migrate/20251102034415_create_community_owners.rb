class CreateCommunityOwners < ActiveRecord::Migration[6.1]
  def change
    create_table :community_owners do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :community, null: false, foreign_key: true

      t.timestamps
    end
  end
end
