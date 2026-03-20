class AddOnboardingToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :onboarding_done, :boolean
  end
end
