class AddColumnCustomers < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :introduction, :text
    add_column :customers, :part, :integer
    add_column :customers, :sex, :integer
    add_column :customers, :birthday, :date
    add_column :customers, :favorite_artist, :string
    add_column :customers, :url, :text
  end

  def down
    remove_column :customers, :introduction, :text
    remove_column :customers, :part, :integer
    remove_column :customers, :sex, :integer
    remove_column :customers, :birthday, :date
    remove_column :customers, :favorite_artist, :string
    remove_column :customers, :url, :text
  end
end
