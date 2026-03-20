class AddTagsToPosts < ActiveRecord::Migration[6.1]
  def change
    add_column :posts, :tags, :string
  end
end
