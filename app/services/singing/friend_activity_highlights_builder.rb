module Singing
  class FriendActivityHighlightsBuilder
    DEFAULT_LIMIT = 3

    Result = Struct.new(:highlights, keyword_init: true) do
      def active?
        highlights.present?
      end
    end

    Highlight = Struct.new(
      :customer_id,
      :display_name,
      :image_url,
      :icon,
      :message,
      :occurred_at,
      :profile_path,
      keyword_init: true
    )

    Activity = Struct.new(:customer_id, :type, :occurred_at, keyword_init: true)

    def self.call(customer, limit: DEFAULT_LIMIT)
      new(customer, limit: limit).call
    end

    def initialize(customer, limit: DEFAULT_LIMIT)
      @customer = customer
      @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
    end

    def call
      Result.new(highlights: build_highlights)
    end

    private

    def build_highlights
      return [] if @customer.nil? || friend_ids.blank?

      recent_activities
        .sort_by { |activity| -(activity.occurred_at&.to_i || 0) }
        .first(@limit)
        .filter_map { |activity| highlight_for(activity) }
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def recent_activities
      completed_diagnosis_activities +
        reaction_sent_activities +
        reaction_received_activities +
        ai_challenge_progress_activities +
        daily_challenge_progress_activities
    end

    def completed_diagnosis_activities
      SingingDiagnosis
        .completed
        .where(customer_id: friend_ids)
        .select(:customer_id, :created_at, :diagnosed_at)
        .order(created_at: :desc)
        .limit(@limit * 3)
        .map do |diagnosis|
          Activity.new(
            customer_id: diagnosis.customer_id,
            type: :diagnosis,
            occurred_at: diagnosis.diagnosed_at || diagnosis.created_at
          )
        end
    end

    def reaction_sent_activities
      SingingProfileReaction
        .where(customer_id: friend_ids)
        .where.not(target_customer_id: @customer.id)
        .select(:customer_id, :target_customer_id, :created_at)
        .order(created_at: :desc)
        .limit(@limit * 3)
        .map do |reaction|
          Activity.new(customer_id: reaction.customer_id, type: :reaction_sent, occurred_at: reaction.created_at)
        end
    end

    def reaction_received_activities
      SingingProfileReaction
        .where(target_customer_id: friend_ids)
        .where.not(customer_id: @customer.id)
        .select(:customer_id, :target_customer_id, :created_at)
        .order(created_at: :desc)
        .limit(@limit * 3)
        .map do |reaction|
          Activity.new(customer_id: reaction.target_customer_id, type: :reaction_received, occurred_at: reaction.created_at)
        end
    end

    def ai_challenge_progress_activities
      return [] unless Object.const_defined?(:SingingAiChallengeProgress)

      SingingAiChallengeProgress
        .where(customer_id: friend_ids)
        .where("tried = ? OR completed = ? OR next_diagnosis_planned = ?", true, true, true)
        .select(:customer_id, :updated_at, :completed_at)
        .order(updated_at: :desc)
        .limit(@limit * 3)
        .map do |progress|
          Activity.new(
            customer_id: progress.customer_id,
            type: :challenge_progress,
            occurred_at: progress.completed_at || progress.updated_at
          )
        end
    end

    def daily_challenge_progress_activities
      SingingDailyChallengeProgress
        .where(customer_id: friend_ids)
        .where.not(completed_at: nil)
        .select(:customer_id, :completed_at)
        .order(completed_at: :desc)
        .limit(@limit * 3)
        .map do |progress|
          Activity.new(customer_id: progress.customer_id, type: :challenge_progress, occurred_at: progress.completed_at)
        end
    end

    def highlight_for(activity)
      customer = customers_by_id[activity.customer_id]
      return if customer.nil?

      display_name = display_name(customer)

      Highlight.new(
        customer_id: customer.id,
        display_name: display_name,
        image_url: image_url_for(customer),
        icon: icon_for(activity.type),
        message: message_for(activity.type, display_name),
        occurred_at: activity.occurred_at,
        profile_path: "/singing/users/#{customer.id}"
      )
    end

    def friend_ids
      @friend_ids ||= Array(music_friends&.friends)
        .map(&:customer_id)
        .compact
        .uniq
    end

    def music_friends
      @music_friends ||= Singing::MusicFriendsBuilder.call(@customer, limit: @limit)
    end

    def customers_by_id
      @customers_by_id ||= Customer
        .where(id: friend_ids)
        .includes(profile_image_attachment: :blob)
        .index_by(&:id)
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

    def icon_for(type)
      {
        diagnosis: "🎤",
        reaction_sent: "🔥",
        reaction_received: "👏",
        challenge_progress: "🏆"
      }.fetch(type, "♪")
    end

    def message_for(type, display_name)
      case type
      when :diagnosis
        "#{display_name}さんが最近、歌唱診断を完了しました"
      when :reaction_sent
        "#{display_name}さんが仲間を応援しました"
      when :reaction_received
        "#{display_name}さんに仲間から応援が届きました"
      when :challenge_progress
        "#{display_name}さんがチャレンジを進めています"
      else
        "#{display_name}さんが音楽を楽しんでいます"
      end
    end
  end
end
