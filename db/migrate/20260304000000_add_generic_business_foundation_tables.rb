class AddGenericBusinessFoundationTables < ActiveRecord::Migration[6.1]
  def change
    create_table :workspaces do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :industry_code
      t.json :settings

      t.timestamps
    end
    add_index :workspaces, :slug, unique: true

    create_table :workspace_memberships do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.datetime :joined_at

      t.timestamps
    end
    add_index :workspace_memberships, [:workspace_id, :customer_id], unique: true

    create_table :workspace_roles do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :role_key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :system_role, null: false, default: false

      t.timestamps
    end
    add_index :workspace_roles, [:workspace_id, :role_key], unique: true

    create_table :workspace_role_assignments do |t|
      t.references :workspace_membership, null: false, foreign_key: true
      t.references :workspace_role, null: false, foreign_key: true

      t.timestamps
    end
    add_index :workspace_role_assignments,
              [:workspace_membership_id, :workspace_role_id],
              unique: true,
              name: "index_workspace_role_assignments_on_membership_and_role"

    create_table :categories do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :categories, [:workspace_id, :kind, :name], unique: true

    create_table :category_assignments do |t|
      t.references :category, null: false, foreign_key: true
      t.string :target_type, null: false
      t.bigint :target_id, null: false

      t.timestamps
    end
    add_index :category_assignments, [:target_type, :target_id]
    add_index :category_assignments,
              [:category_id, :target_type, :target_id],
              unique: true,
              name: "index_category_assignments_on_category_and_target"

    create_table :custom_field_definitions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :entity_type, null: false
      t.string :field_key, null: false
      t.string :label, null: false
      t.string :field_type, null: false
      t.boolean :required, null: false, default: false
      t.json :options
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :custom_field_definitions,
              [:workspace_id, :entity_type, :field_key],
              unique: true,
              name: "index_custom_field_definitions_on_workspace_and_entity_and_key"

    create_table :custom_field_values do |t|
      t.references :custom_field_definition, null: false, foreign_key: true
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.text :value_text
      t.decimal :value_number, precision: 15, scale: 4
      t.boolean :value_boolean
      t.date :value_date
      t.json :value_json

      t.timestamps
    end
    add_index :custom_field_values, [:target_type, :target_id]
    add_index :custom_field_values,
              [:custom_field_definition_id, :target_type, :target_id],
              unique: true,
              name: "index_custom_field_values_on_definition_and_target"

    create_table :applications do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.string :status, null: false, default: "pending"
      t.text :message
      t.datetime :submitted_at
      t.datetime :reviewed_at

      t.timestamps
    end
    add_index :applications, [:target_type, :target_id]
    add_index :applications, :status

    create_table :approvals do |t|
      t.references :application, null: false, foreign_key: true
      t.references :reviewer, null: false, foreign_key: { to_table: :customers }
      t.string :decision, null: false
      t.text :comment
      t.datetime :decided_at

      t.timestamps
    end
    add_index :approvals, :decision
  end
end
