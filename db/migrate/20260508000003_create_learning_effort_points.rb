class CreateLearningEffortPoints < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_effort_points do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :learning_student, null: false, foreign_key: true
      t.string :point_type, null: false
      t.integer :points, null: false, default: 0
      t.string :description, limit: 100
      t.date :earned_on, null: false
      t.timestamps
    end

    add_index :learning_effort_points, [:learning_student_id, :earned_on],
              name: "index_learning_effort_points_on_student_and_date"
    add_index :learning_effort_points, [:learning_student_id, :point_type, :earned_on],
              name: "index_learning_effort_points_on_student_type_date"
  end
end
