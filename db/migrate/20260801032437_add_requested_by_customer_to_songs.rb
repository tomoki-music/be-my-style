class AddRequestedByCustomerToSongs < ActiveRecord::Migration[6.1]
  def change
    add_reference :songs, :requested_by_customer, foreign_key: { to_table: :customers }, index: true
  end
end
