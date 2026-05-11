class AddTeacherReviewFieldsToLearningAssignments < ActiveRecord::Migration[6.1]
  def change
    add_column :learning_assignments, :submitted_at, :datetime
    add_column :learning_assignments, :reviewed_at, :datetime
    add_reference :learning_assignments, :reviewed_by, foreign_key: { to_table: :customers }
    add_column :learning_assignments, :review_comment, :text
    add_column :learning_assignments, :reaction_message, :string
  end
end
