class AddBusinessFieldsToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :job, :string
    add_column :customers, :skills, :text
    add_column :customers, :achievements, :text
  end
end
