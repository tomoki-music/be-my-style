module Learning
  class NotificationSetting < ApplicationRecord
    self.table_name = "learning_notification_settings"

    DELIVERY_CHANNELS = {
      "manual" => "手動コピー",
      "email" => "メール",
      "line" => "LINE"
    }.freeze

    belongs_to :customer

    validates :delivery_channel, presence: true, inclusion: { in: DELIVERY_CHANNELS.keys }

    def self.effective_for(customer)
      customer.learning_notification_setting || new(customer: customer)
    end

    def self.reminder_enabled_for?(customer)
      effective_for(customer).reminder_enabled?
    end

    def delivery_channel_label
      DELIVERY_CHANNELS.fetch(delivery_channel, DELIVERY_CHANNELS["manual"])
    end
  end
end
