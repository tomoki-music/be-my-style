class AddSessionCreditFieldsToJoinPartCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :join_part_customers, :session_credit_applied, :boolean, null: false, default: false
    add_column :join_part_customers, :session_credit_amount, :integer, null: false, default: 0
    add_column :join_part_customers, :plan_snapshot, :string
  end
end
