class CreateLearningAssignmentReviewHistories < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_assignment_review_histories do |t|
      t.references :learning_assignment, null: false,
                   foreign_key: true,
                   index: { name: "idx_review_hist_on_assignment_id" }
      t.references :reviewer, foreign_key: { to_table: :customers }, null: true,
                   index: { name: "idx_review_hist_on_reviewer_id" }
      t.string :action, null: false
      t.text :comment
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.timestamps
    end

    add_index :learning_assignment_review_histories, [:learning_assignment_id, :created_at],
              name: "idx_review_hist_on_assignment_and_created_at"
  end
end
