class CreateCommunityCustomers < ActiveRecord::Migration[6.1]
  def change
    create_table :community_customers do |t|
      t.references  :customer,  index: true, foreign_key: true
      t.references  :community, index: true, foreign_key: true
      t.timestamps
    end
  end
end
