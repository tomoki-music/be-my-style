class AddColumnCustomers < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :introduction, :text
    add_column :customers, :part, :integer
  end

  def down
    remove_column :customers, :introduction, :text
    remove_column :customers, :part, :integer
  end
end
