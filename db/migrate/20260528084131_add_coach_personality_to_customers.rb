class AddCoachPersonalityToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :singing_coach_personality, :integer, default: 0, null: false
  end
end
