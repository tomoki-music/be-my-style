class CreateAdminNotifications < ActiveRecord::Migration[6.1]
  def up
    unless table_exists?(:admin_notifications)
      create_table :admin_notifications do |t|
        t.references :admin, null: false, foreign_key: true
        t.references :customer, null: false, foreign_key: true
        t.string :action, null: false, default: "", limit: 50
        t.string :plan, null: false, limit: 30
        t.string :stripe_subscription_id, limit: 100
        t.text :message
        t.boolean :checked, null: false, default: false

        t.timestamps
      end
    end

    add_reference :admin_notifications, :admin, null: false, foreign_key: true unless column_exists?(:admin_notifications, :admin_id)
    add_reference :admin_notifications, :customer, null: false, foreign_key: true unless column_exists?(:admin_notifications, :customer_id)
    add_column :admin_notifications, :action, :string, null: false, default: "", limit: 50 unless column_exists?(:admin_notifications, :action)
    add_column :admin_notifications, :plan, :string, null: false, limit: 30 unless column_exists?(:admin_notifications, :plan)
    add_column :admin_notifications, :stripe_subscription_id, :string, limit: 100 unless column_exists?(:admin_notifications, :stripe_subscription_id)
    add_column :admin_notifications, :message, :text unless column_exists?(:admin_notifications, :message)
    add_column :admin_notifications, :checked, :boolean, null: false, default: false unless column_exists?(:admin_notifications, :checked)
    add_timestamps :admin_notifications, null: false unless column_exists?(:admin_notifications, :created_at)

    change_column :admin_notifications, :action, :string, null: false, default: "", limit: 50 if column_exists?(:admin_notifications, :action)
    change_column :admin_notifications, :plan, :string, null: false, limit: 30 if column_exists?(:admin_notifications, :plan)
    change_column :admin_notifications, :stripe_subscription_id, :string, limit: 100 if column_exists?(:admin_notifications, :stripe_subscription_id)

    add_foreign_key :admin_notifications, :admins unless foreign_key_exists?(:admin_notifications, :admins)
    add_foreign_key :admin_notifications, :customers unless foreign_key_exists?(:admin_notifications, :customers)

    add_index :admin_notifications,
      [:admin_id, :customer_id, :action, :plan, :stripe_subscription_id],
      unique: true,
      name: "index_admin_notifications_on_subscription_event" unless index_exists?(:admin_notifications, [:admin_id, :customer_id, :action, :plan, :stripe_subscription_id], name: "index_admin_notifications_on_subscription_event")
  end

  def down
    drop_table :admin_notifications if table_exists?(:admin_notifications)
  end
end
