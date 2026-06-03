module Singing
  class ReturnMotivationBuilder
    ReturnMotivation = Struct.new(
      :visible,
      :title,
      :message,
      :cta_label,
      :cta_path,
      :latest_activity_at,
      :activity_source,
      keyword_init: true
    )

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return hidden unless @customer.present?

      activity = latest_activity
      inactive_days = days_since(activity&.last)
      return hidden(latest_activity_at: activity&.last, activity_source: activity&.first) if inactive_days.present? && inactive_days < 3

      build_card(inactive_days, activity)
    end

    private

    def build_card(inactive_days, activity)
      case inactive_days
      when 30..Float::INFINITY
        card(
          title: "また歌いたくなったら、",
          message: "いつでも帰ってきてください 🌱",
          activity: activity
        )
      when 7..Float::INFINITY
        card(
          title: "あなたの音楽を待っています 🎤",
          message: "完璧じゃなくて大丈夫。\nまずは一歩だけ。",
          activity: activity
        )
      else
        card(
          title: "おかえりなさい 🎵",
          message: "少し間が空いても大丈夫。\nまた今日から音楽を楽しみましょう。",
          activity: activity
        )
      end
    end

    def card(title:, message:, activity:)
      activity_source = activity&.first
      cta = cta_for(activity_source)

      ReturnMotivation.new(
        visible: true,
        title: title,
        message: message_for(activity_source, message),
        cta_label: cta[:label],
        cta_path: cta[:path],
        latest_activity_at: activity&.last,
        activity_source: activity_source
      )
    end

    def message_for(activity_source, fallback_message)
      case activity_source
      when :diagnosis
        "前回の診断から少し間が空きました。\nまた今日から、自分のペースで歌を楽しみましょう。"
      when :reaction_sent
        "前に仲間を応援していましたね。\nまた音楽の輪に戻ってみませんか。"
      when :reaction_received
        "仲間からの応援が届いています。\nまた少しずつ、歌との時間を楽しみましょう。"
      when :challenge_progress
        "前に挑戦していたテーマがあります。\n完璧じゃなくて大丈夫。まずは一歩だけ。"
      when nil
        "ここから音楽の旅をはじめましょう。"
      else
        fallback_message
      end
    end

    def cta_for(activity_source)
      case activity_source
      when :diagnosis
        { label: "今日の診断をする", path: routes.new_singing_diagnosis_path }
      when :reaction_sent
        { label: "仲間の活動を見る", path: "#community-feed" }
      when :reaction_received
        { label: "応援を見に行く", path: "#encouragement-inbox" }
      when :challenge_progress
        { label: "チャレンジを見る", path: routes.singing_challenges_path }
      else
        { label: "まずは診断してみる", path: routes.new_singing_diagnosis_path }
      end
    end

    def routes
      Rails.application.routes.url_helpers
    end

    def hidden(latest_activity_at: nil, activity_source: nil)
      ReturnMotivation.new(
        visible: false,
        title: nil,
        message: nil,
        cta_label: nil,
        cta_path: nil,
        latest_activity_at: latest_activity_at,
        activity_source: activity_source
      )
    end

    def days_since(latest_at)
      return nil if latest_at.blank?

      ((Time.zone.now - latest_at) / 1.day).floor
    rescue NoMethodError, TypeError
      nil
    end

    def latest_activity
      @latest_activity ||= activity_candidates.select { |(_, occurred_at)| occurred_at.present? }.max_by(&:last)
    end

    def activity_candidates
      [
        [:diagnosis, latest_completed_diagnosis_at],
        [:reaction_sent, latest_profile_reaction_sent_at],
        [:reaction_received, latest_profile_reaction_received_at],
        [:challenge_progress, latest_ai_challenge_progress_at]
      ]
    end

    def latest_completed_diagnosis_at
      SingingDiagnosis.completed.where(customer: @customer).maximum(:created_at)
    rescue NameError, NoMethodError
      nil
    end

    def latest_profile_reaction_sent_at
      SingingProfileReaction.where(customer: @customer).maximum(:created_at)
    rescue NameError, NoMethodError
      nil
    end

    def latest_profile_reaction_received_at
      SingingProfileReaction.where(target_customer_id: @customer.id).maximum(:created_at)
    rescue NameError, NoMethodError
      nil
    end

    def latest_ai_challenge_progress_at
      return nil unless Object.const_defined?(:SingingAiChallengeProgress)

      SingingAiChallengeProgress.where(customer: @customer).maximum(:updated_at)
    rescue NameError, NoMethodError, ActiveRecord::StatementInvalid
      nil
    end
  end
end
