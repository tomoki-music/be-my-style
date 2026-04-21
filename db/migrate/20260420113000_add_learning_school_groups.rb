class AddLearningSchoolGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_school_groups do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :name, null: false
      t.text :memo

      t.timestamps
    end

    add_index :learning_school_groups, [:customer_id, :name], unique: true

    add_reference :learning_students, :learning_school_group, foreign_key: true
    add_index :learning_students, [:customer_id, :learning_school_group_id], name: "index_learning_students_on_customer_and_school_group"
  end
end
