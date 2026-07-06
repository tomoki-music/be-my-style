class ChangeCommentAndRequestBodyToText < ActiveRecord::Migration[6.1]
  def up
    change_column :comments, :comment, :text
    change_column :requests, :request, :text
  end

  def down
    change_column :comments, :comment, :string
    change_column :requests, :request, :string
  end
end
