class CreateLearningNotificationLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_notification_logs do |t|
      t.references :customer, null: false, foreign_key: true, index: false
      t.references :learning_student, null: true, foreign_key: true, index: false
      t.string :notification_type, null: false
      t.string :level
      t.string :delivery_channel, null: false, default: "manual"
      t.string :status, null: false, default: "previewed"
      t.string :title
      t.text :message, null: false
      t.string :recommended_action
      t.datetime :generated_at, null: false
      t.datetime :sent_at
      t.text :error_message
      t.json :metadata

      t.timestamps
    end

    add_index :learning_notification_logs, :customer_id
    add_index :learning_notification_logs, :learning_student_id
    add_index :learning_notification_logs, :notification_type
    add_index :learning_notification_logs, :status
    add_index :learning_notification_logs, :generated_at
    add_index :learning_notification_logs,
              [:customer_id, :learning_student_id, :notification_type, :generated_at],
              name: "index_learning_notification_logs_on_daily_dedupe_lookup"
  end
end
