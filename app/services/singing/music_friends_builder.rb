module Singing
  class MusicFriendsBuilder
    DEFAULT_LIMIT = 3
    WINDOW_DAYS = 30

    Result = Struct.new(:friends, keyword_init: true) do
      def active?
        friends.present?
      end
    end

    Friend = Struct.new(
      :customer_id,
      :display_name,
      :image_url,
      :message,
      :profile_path,
      keyword_init: true
    )

    Interaction = Struct.new(:customer_id, :sent, :received, :latest_at, keyword_init: true) do
      def score
        sent.to_i + received.to_i
      end

      def touch!(sent: 0, received: 0, occurred_at: nil)
        self.sent += sent.to_i
        self.received += received.to_i
        self.latest_at = [latest_at, occurred_at].compact.max
      end
    end

    def self.call(customer, limit: DEFAULT_LIMIT)
      new(customer, limit: limit).call
    end

    def initialize(customer, limit: DEFAULT_LIMIT)
      @customer = customer
      @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
    end

    def call
      Result.new(friends: build_friends)
    end

    private

    def build_friends
      return [] if @customer.nil?

      sorted_interactions
        .first(@limit)
        .filter_map { |interaction| friend_for(interaction) }
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def sorted_interactions
      interactions_by_customer_id.values
        .select { |interaction| interaction.customer_id.present? && interaction.score.positive? }
        .sort_by { |interaction| [-interaction.score, -(interaction.latest_at&.to_i || 0), display_name_for(interaction.customer_id)] }
    end

    def interactions_by_customer_id
      @interactions_by_customer_id ||= Hash.new do |hash, customer_id|
        hash[customer_id] = Interaction.new(customer_id: customer_id, sent: 0, received: 0, latest_at: nil)
      end.tap do |interactions|
        recent_sent_reactions.each do |reaction|
          interactions[reaction.target_customer_id].touch!(sent: 1, occurred_at: reaction.created_at)
        end

        recent_received_reactions.each do |reaction|
          interactions[reaction.customer_id].touch!(received: 1, occurred_at: reaction.created_at)
        end
      end
    end

    def recent_sent_reactions
      @recent_sent_reactions ||= SingingProfileReaction
        .where(customer_id: @customer.id, created_at: window_range)
        .select(:customer_id, :target_customer_id, :created_at)
        .to_a
    end

    def recent_received_reactions
      @recent_received_reactions ||= SingingProfileReaction
        .where(target_customer_id: @customer.id, created_at: window_range)
        .select(:customer_id, :target_customer_id, :created_at)
        .to_a
    end

    def friend_for(interaction)
      customer = customers_by_id[interaction.customer_id]
      return if customer.nil?

      Friend.new(
        customer_id: customer.id,
        display_name: display_name(customer),
        image_url: image_url_for(customer),
        message: message_for(interaction),
        profile_path: "/singing/users/#{customer.id}"
      )
    end

    def customers_by_id
      @customers_by_id ||= Customer
        .where(id: interactions_by_customer_id.keys.compact)
        .includes(profile_image_attachment: :blob)
        .index_by(&:id)
    end

    def display_name_for(customer_id)
      display_name(customers_by_id[customer_id])
    end

    def display_name(customer)
      customer&.name.presence || "メンバー"
    end

    def image_url_for(customer)
      return unless customer&.profile_image&.attached?

      Rails.application.routes.url_helpers.rails_blob_path(customer.profile_image, only_path: true)
    rescue ArgumentError, NoMethodError
      nil
    end

    def message_for(interaction)
      if interaction.sent.positive? && interaction.received.positive?
        "応援のやり取りがありました"
      elsif interaction.sent.positive?
        "最近あなたが応援した仲間です"
      else
        "最近あなたを応援してくれた仲間です"
      end
    end

    def window_range
      WINDOW_DAYS.days.ago.beginning_of_day..Time.current
    end
  end
end
