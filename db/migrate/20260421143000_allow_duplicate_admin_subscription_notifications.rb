class AllowDuplicateAdminSubscriptionNotifications < ActiveRecord::Migration[6.1]
  INDEX_NAME = "index_admin_notifications_on_subscription_event".freeze
  INDEX_COLUMNS = [:admin_id, :customer_id, :action, :plan, :stripe_subscription_id].freeze

  def up
    return unless table_exists?(:admin_notifications)

    if index_exists?(:admin_notifications, nil, name: INDEX_NAME)
      remove_index :admin_notifications, name: INDEX_NAME
    end

    unless index_exists?(:admin_notifications, INDEX_COLUMNS, name: INDEX_NAME)
      add_index :admin_notifications, INDEX_COLUMNS, name: INDEX_NAME
    end
  end

  def down
    return unless table_exists?(:admin_notifications)

    if index_exists?(:admin_notifications, nil, name: INDEX_NAME)
      remove_index :admin_notifications, name: INDEX_NAME
    end

    unless index_exists?(:admin_notifications, INDEX_COLUMNS, name: INDEX_NAME)
      add_index :admin_notifications, INDEX_COLUMNS, unique: true, name: INDEX_NAME
    end
  end
end