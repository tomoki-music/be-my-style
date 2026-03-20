class AddProjectIdToPosts < ActiveRecord::Migration[6.1]
  def change
    add_column :posts, :project_id, :integer
  end
end
