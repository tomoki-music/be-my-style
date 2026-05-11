class CreateLearningLineMessageTemplates < ActiveRecord::Migration[6.1]
  def change
    create_table :learning_line_message_templates do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :title, null: false
      t.string :category, null: false
      t.text :body, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :learning_line_message_templates, [:customer_id, :category], name: "idx_learning_line_templates_on_customer_category"
    add_index :learning_line_message_templates, [:customer_id, :active], name: "idx_learning_line_templates_on_customer_active"
  end
end
