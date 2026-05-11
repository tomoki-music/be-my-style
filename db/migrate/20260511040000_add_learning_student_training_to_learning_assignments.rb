class AddLearningStudentTrainingToLearningAssignments < ActiveRecord::Migration[6.1]
  def change
    add_reference :learning_assignments,
                  :learning_student_training,
                  foreign_key: true,
                  index: { name: "index_learning_assignments_on_student_training_id" }

    add_index :learning_assignments,
              [:learning_student_id, :learning_student_training_id, :status],
              name: "index_learning_assignments_on_student_training_status"
  end
end
