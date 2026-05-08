class CreateLearningMonthlyReports < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_monthly_reports do |t|
      t.references :customer, null: false, foreign_key: true
      t.date :report_month, null: false
      t.integer :total_students, default: 0, null: false
      t.integer :total_progress_logs, default: 0, null: false
      t.integer :total_achieved_trainings, default: 0, null: false
      t.decimal :avg_achievement_rate, precision: 5, scale: 2, default: 0
      t.string :status, default: "generated", null: false
      t.timestamps
    end

    add_index :learning_monthly_reports, [:customer_id, :report_month],
              unique: true, name: "index_learning_monthly_reports_on_customer_and_month"
  end
end
