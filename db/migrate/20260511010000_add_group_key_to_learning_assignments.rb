class AddGroupKeyToLearningAssignments < ActiveRecord::Migration[6.1]
  def change
    add_column :learning_assignments, :assignment_group_key, :string
    add_index :learning_assignments, [:customer_id, :assignment_group_key], name: "index_learning_assignments_on_customer_group_key"
  end
end
