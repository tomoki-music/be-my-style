class AddRequiredPlanForEventCreationToCommunities < ActiveRecord::Migration[6.1]
  def change
    add_column :communities, :required_plan_for_event_creation, :string, null: false, default: "core"
  end
end
