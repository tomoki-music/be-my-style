class CreateLearningManagementTables < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_students do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :name, null: false
      t.string :main_part, null: false
      t.string :grade
      t.text :memo
      t.string :status, null: false, default: "active"

      t.timestamps
    end
    add_index :learning_students, [:customer_id, :name]
    add_index :learning_students, [:customer_id, :status]

    create_table :learning_student_parts do |t|
      t.references :learning_student, null: false, foreign_key: true
      t.string :part, null: false
      t.boolean :primary, null: false, default: false

      t.timestamps
    end
    add_index :learning_student_parts, [:learning_student_id, :part], unique: true, name: "index_learning_student_parts_on_student_and_part"

    create_table :learning_training_masters do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :part, null: false
      t.string :period, null: false
      t.string :level, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.text :achievement_criteria
      t.string :frequency
      t.boolean :is_band_training, null: false, default: false

      t.timestamps
    end
    add_index :learning_training_masters, [:customer_id, :part]
    add_index :learning_training_masters, [:customer_id, :period]
    add_index :learning_training_masters, [:customer_id, :level]

    create_table :learning_student_trainings do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :learning_student, null: false, foreign_key: true
      t.references :learning_training_master, foreign_key: true
      t.string :part, null: false
      t.string :period, null: false
      t.string :level, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.text :achievement_criteria
      t.string :frequency
      t.string :status, null: false, default: "not_started"
      t.string :achievement_mark, null: false, default: "cross"
      t.string :weekly_goal
      t.text :teacher_comment
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :learning_student_trainings, [:learning_student_id, :position], name: "index_learning_student_trainings_on_student_and_position"
    add_index :learning_student_trainings, [:customer_id, :status]

    create_table :learning_progress_logs do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :learning_student, null: false, foreign_key: true
      t.references :learning_student_training, foreign_key: true
      t.string :part, null: false
      t.string :training_title, null: false
      t.date :practiced_on, null: false
      t.string :achievement_mark, null: false, default: "triangle"
      t.text :comment

      t.timestamps
    end
    add_index :learning_progress_logs, [:learning_student_id, :practiced_on], name: "index_learning_progress_logs_on_student_and_date"
    add_index :learning_progress_logs, [:customer_id, :practiced_on]

    create_table :learning_bands do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :name, null: false
      t.text :memo

      t.timestamps
    end
    add_index :learning_bands, [:customer_id, :name], unique: true

    create_table :learning_band_trainings do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :learning_band, null: false, foreign_key: true
      t.references :learning_training_master, foreign_key: true
      t.string :part, null: false, default: "band"
      t.string :period, null: false
      t.string :level, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.text :achievement_criteria
      t.string :frequency
      t.string :status, null: false, default: "not_started"
      t.string :achievement_mark, null: false, default: "cross"
      t.text :teacher_comment
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :learning_band_trainings, [:learning_band_id, :position], name: "index_learning_band_trainings_on_band_and_position"
  end
end
