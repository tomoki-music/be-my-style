class AddSchoolCodeToLearningSchoolGroups < ActiveRecord::Migration[6.1]
  def change
    add_column :learning_school_groups, :school_code, :string, limit: 20
    add_column :learning_school_groups, :advisor_name, :string, limit: 100
    add_index :learning_school_groups, [:customer_id, :school_code],
              unique: true, name: "index_learning_school_groups_on_customer_and_code",
              where: "school_code IS NOT NULL"
  end
end
