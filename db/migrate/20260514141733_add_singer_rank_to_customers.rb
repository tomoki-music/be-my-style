class AddSingerRankToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :singing_xp, :integer, default: 0, null: false
    add_column :customers, :singing_level, :integer, default: 1, null: false
  end
end
