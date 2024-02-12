class AddConfirmMailToCustomer < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :confirm_mail, :boolean, default: true
    Customer.update_all(confirm_mail: true)
  end

  def down
    remove_column :customers, :confirm_mail, :boolean, default: true
  end
end
