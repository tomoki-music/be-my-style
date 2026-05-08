class AddNicknameAndPointsToLearningStudents < ActiveRecord::Migration[6.1]
  def change
    add_column :learning_students, :nickname, :string, limit: 30
    add_column :learning_students, :tutorial_completed, :boolean, default: false, null: false
    add_column :learning_students, :total_effort_points, :integer, default: 0, null: false
  end
end
