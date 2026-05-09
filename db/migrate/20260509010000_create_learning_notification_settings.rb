class CreateLearningNotificationSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_notification_settings do |t|
      t.references :customer, null: false, foreign_key: true, index: false
      t.boolean :reminder_enabled, null: false, default: true
      t.boolean :teacher_summary_enabled, null: false, default: true
      t.boolean :student_reactivation_enabled, null: false, default: true
      t.string :delivery_channel, null: false, default: "manual"

      t.timestamps
    end

    add_index :learning_notification_settings, :customer_id, unique: true
  end
end
