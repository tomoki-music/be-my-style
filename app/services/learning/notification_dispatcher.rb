module Learning
  class NotificationDispatcher
    Delivery = Struct.new(:reminder, :channel, :status, keyword_init: true)

    CHANNELS = %i[line email app].freeze

    def initialize(customer, channels: [])
      @customer = customer
      @channels = Array(channels).map(&:to_sym)
    end

    def preview
      reminders
    end

    def dispatch
      channels = @channels & CHANNELS
      return [] if channels.empty?

      reminders.flat_map do |reminder|
        channels.map do |channel|
          Delivery.new(reminder: reminder, channel: channel, status: :planned)
        end
      end
    end

    private

    def reminders
      @reminders ||= ReminderService.for_customer(@customer)
    end
  end
end
