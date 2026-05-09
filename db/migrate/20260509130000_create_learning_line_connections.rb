class CreateLearningLineConnections < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_line_connections do |t|
      t.references :customer, null: false, foreign_key: true, index: false
      t.references :learning_student, null: true, foreign_key: true, index: false
      t.string :line_user_id, null: false
      t.string :display_name
      t.string :status, null: false, default: "pending"
      t.datetime :connected_at
      t.datetime :last_notified_at
      t.json :metadata

      t.timestamps
    end

    add_index :learning_line_connections, :customer_id
    add_index :learning_line_connections, :learning_student_id
    add_index :learning_line_connections, :line_user_id
    add_index :learning_line_connections, :status
  end
end
