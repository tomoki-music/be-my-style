class AddReactionFieldsToLearningNotifications < ActiveRecord::Migration[6.1]
  def change
    add_column :learning_notification_logs, :reaction_received, :boolean, null: false, default: false
    add_column :learning_notification_logs, :reacted_at, :datetime
    add_column :learning_notification_logs, :reaction_message, :string
    add_column :learning_students, :last_learning_action_at, :datetime

    add_index :learning_notification_logs,
              [:learning_student_id, :reaction_received, :sent_at],
              name: "index_learning_notification_logs_on_student_reaction"
    add_index :learning_notification_logs, :reacted_at
    add_index :learning_students, :last_learning_action_at
  end
end
