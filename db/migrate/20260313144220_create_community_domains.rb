class CreateCommunityDomains < ActiveRecord::Migration[6.1]
  def change
    create_table :community_domains do |t|
      t.references :community, null: false, foreign_key: true
      t.references :domain, null: false, foreign_key: true

      t.timestamps
    end
  end
end
