class AddUniqueIndexToCommunityOwners < ActiveRecord::Migration[6.1]
  def change
    add_index :community_owners, [:community_id, :customer_id], unique: true, name: "index_community_owners_on_community_id_and_customer_id"
  end
end
