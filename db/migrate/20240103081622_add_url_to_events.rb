class AddUrlToEvents < ActiveRecord::Migration[6.1]
  def up
    add_column :events, :url, :text
    add_column :events, :url_comment, :string
  end

  def down
    remove_column :events, :url, :text
    remove_column :events, :url_comment, :string
  end
end
