class CreateLearningSchoolApplications < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_school_applications do |t|
      t.string  :school_name,   null: false, limit: 100
      t.string  :advisor_name,  null: false, limit: 50
      t.string  :email,         null: false, limit: 255
      t.integer :student_count
      t.text    :message
      t.string  :status,        null: false, default: "pending"
      t.timestamps
    end

    add_index :learning_school_applications, :email
    add_index :learning_school_applications, :status
  end
end
