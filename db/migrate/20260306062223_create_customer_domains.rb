class CreateCustomerDomains < ActiveRecord::Migration[6.1]
  def change
    create_table :customer_domains do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :domain, null: false, foreign_key: true

      t.timestamps
    end

    add_index :customer_domains, [:customer_id, :domain_id], unique: true
  end
end
