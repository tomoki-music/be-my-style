class AddUniqueIndexToSubscriptionsStripeSubscriptionId < ActiveRecord::Migration[6.1]
  def up
    # MySQLでNULLは重複判定から除外されるため、stripe_subscription_idがNULLの行が複数あっても問題ない
    add_index :subscriptions, :stripe_subscription_id,
              unique: true,
              name: "index_subscriptions_on_stripe_subscription_id_unique"
  end

  def down
    remove_index :subscriptions, name: "index_subscriptions_on_stripe_subscription_id_unique"
  end
end
