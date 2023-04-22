class AddColumnCustomers < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :introduction, :text
    add_column :customers, :sex, :integer
    add_column :customers, :birthday, :date
    add_column :customers, :favorite_artist, :string
    add_column :customers, :url, :text
    add_column :customers, :prefecture_id, :integer
  end

  def down
    remove_column :customers, :introduction, :text
    remove_column :customers, :sex, :integer
    remove_column :customers, :birthday, :date
    remove_column :customers, :favorite_artist, :string
    remove_column :customers, :url, :text
    remove_column :customers, :prefecture_id, :integer
  end
end
