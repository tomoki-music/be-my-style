class CreateLearningAssignments < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_assignments do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :learning_student, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: "pending"
      t.date :due_on
      t.datetime :completed_at

      t.timestamps
    end

    add_index :learning_assignments, :status
    add_index :learning_assignments, :due_on
    add_index :learning_assignments, [:customer_id, :learning_student_id, :status], name: "index_learning_assignments_on_customer_student_status"
    add_index :learning_assignments, [:learning_student_id, :status, :created_at], name: "index_learning_assignments_on_student_status_created_at"
  end
end
