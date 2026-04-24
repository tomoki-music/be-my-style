class AddAiCommentToSingingDiagnoses < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_diagnoses, :ai_comment, :text
    add_column :singing_diagnoses, :ai_comment_status, :integer, null: false, default: 0
    add_column :singing_diagnoses, :ai_comment_failure_reason, :text
    add_column :singing_diagnoses, :ai_commented_at, :datetime

    add_index :singing_diagnoses, :ai_comment_status
  end
end
