module Singing
  class EncouragementInboxBuilder
    INBOX_LIMIT = 5

    InboxItem = Struct.new(
      :customer,
      :reaction_type,
      :message,
      :occurred_at,
      :icon,
      keyword_init: true
    )

    EncouragementInbox = Struct.new(
      :items,
      keyword_init: true
    )

    MESSAGE_MAP = {
      "cheer"     => "応援してくれました",
      "amazing"   => "素晴らしいと感じています",
      "growth"    => "成長を応援しています",
      "listen"    => "また聴きたいと感じています",
      "challenge" => "挑戦を応援しています"
    }.freeze

    def self.call(customer:)
      new(customer: customer).call
    end

    def initialize(customer:)
      @customer = customer
    end

    def call
      return EncouragementInbox.new(items: []) if @customer.nil?

      reactions = SingingProfileReaction
        .where(target_customer_id: @customer.id)
        .order(created_at: :desc)
        .limit(INBOX_LIMIT)
        .includes(:customer)

      items = reactions.filter_map do |r|
        next if r.customer.nil?

        InboxItem.new(
          customer:      r.customer,
          reaction_type: r.reaction_type,
          message:       message_for(r.reaction_type),
          occurred_at:   r.created_at,
          icon:          SingingProfileReaction.emoji_for(r.reaction_type)
        )
      end

      EncouragementInbox.new(items: items)
    rescue StandardError
      EncouragementInbox.new(items: [])
    end

    private

    def message_for(reaction_type)
      MESSAGE_MAP[reaction_type.to_s] || "応援してくれました"
    end
  end
end
