class AddUrlToActivities < ActiveRecord::Migration[6.1]
  def up
    add_column :activities, :url, :text
    add_column :activities, :url_comment, :string
  end

  def down
    remove_column :activities, :url, :text
    remove_column :activities, :url_comment, :string
  end
end
