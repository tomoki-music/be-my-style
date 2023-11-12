class AddColumnToCustomer < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :confirmation_token, :string
    add_column :customers, :confirmed_at, :datetime
    add_column :customers, :confirmation_sent_at, :datetime
    add_column :customers, :unconfirmed_email, :string
  end

  def down
    remove_column :customers, :confirmation_token, :string
    remove_column :customers, :confirmed_at, :datetime
    remove_column :customers, :confirmation_sent_at, :datetime
    remove_column :customers, :unconfirmed_email, :string
  end
end
