class CreatePendingStripeCheckouts < ActiveRecord::Migration[6.1]
  def change
    create_table :pending_stripe_checkouts do |t|
      t.string  :stripe_session_id,      null: false
      t.string  :stripe_customer_id
      t.string  :stripe_subscription_id
      t.string  :stripe_email
      t.string  :plan_key
      t.references :customer, null: true, foreign_key: true
      t.datetime :processed_at

      t.timestamps
    end

    add_index :pending_stripe_checkouts, :stripe_session_id,
              unique: true,
              name: "index_pending_stripe_checkouts_on_session_id_unique"
    add_index :pending_stripe_checkouts, :stripe_email,
              name: "index_pending_stripe_checkouts_on_stripe_email"
  end
end
