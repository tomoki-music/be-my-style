class AddSingingProfileCommentToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :singing_profile_comment, :string, limit: 120
  end
end
