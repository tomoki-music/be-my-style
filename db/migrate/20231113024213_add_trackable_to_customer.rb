class AddTrackableToCustomer < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :sign_in_count, :integer, default: 0, null: false
    add_column :customers, :current_sign_in_at, :datetime
    add_column :customers, :last_sign_in_at, :datetime
    add_column :customers, :current_sign_in_ip, :string
    add_column :customers, :last_sign_in_ip, :string
  end

  def down
    remove_column :customers, :sign_in_count, :integer, default: 0, null: false
    remove_column :customers, :current_sign_in_at, :datetime
    remove_column :customers, :last_sign_in_at, :datetime
    remove_column :customers, :current_sign_in_ip, :string
    remove_column :customers, :last_sign_in_ip, :string
  end
end
