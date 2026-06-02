class PendingStripeCheckout < ApplicationRecord
  belongs_to :customer, optional: true

  scope :unprocessed, -> { where(processed_at: nil) }

  def self.find_unprocessed_for_customer(customer)
    by_customer = unprocessed.where(customer: customer)
    by_email    = unprocessed.where("LOWER(stripe_email) = ?", customer.email.downcase)
    by_customer.or(by_email).order(created_at: :desc).first
  end
end
