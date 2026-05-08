class CreateLearningPortalAccesses < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_portal_accesses do |t|
      t.references :learning_student, null: false, foreign_key: true
      t.date :accessed_on, null: false
      t.integer :streak_count, default: 1, null: false
      t.timestamps
    end

    add_index :learning_portal_accesses, [:learning_student_id, :accessed_on],
              unique: true, name: "index_learning_portal_accesses_unique_daily"
  end
end
