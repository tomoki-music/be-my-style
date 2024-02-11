class AddColumnToEvent < ActiveRecord::Migration[6.1]
  def up
    add_column :events, :event_entry_deadline, :datetime, null: true
    Event.update_all(event_entry_deadline: Time.current)
    change_column :events, :event_entry_deadline, :datetime, null: false
  end

  def down
    remove_column :events, :event_entry_deadline, :datetime
  end
end
