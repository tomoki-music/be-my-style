class AddPostAndProjectToNotifications < ActiveRecord::Migration[6.1]
  def change
    add_column :notifications, :post_id, :integer
    add_column :notifications, :project_id, :integer

    add_index :notifications, :post_id
    add_index :notifications, :project_id
  end
end
