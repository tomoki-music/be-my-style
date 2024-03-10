class AddIsOwnerToCustomers < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :is_owner, :integer
  end

  def down
    remove_column :customers, :is_owner, :integer
  end
end
