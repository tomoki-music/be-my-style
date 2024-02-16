class AddRequestDeadLineToEvents < ActiveRecord::Migration[6.1]
  def up
    add_column :events, :request_deadline, :datetime
  end

  def down
    remove_column :events, :request_deadline, :datetime
  end
end
