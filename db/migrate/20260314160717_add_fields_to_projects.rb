class AddFieldsToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :status, :integer, default: 0
    add_column :projects, :deadline, :datetime
    add_column :projects, :goal, :string
  end
end
