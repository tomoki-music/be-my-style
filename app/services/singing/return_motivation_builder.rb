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

    FALLBACK_MESSAGE_MAP = {
      long_absence: "いつでも帰ってきてください 🌱",
      week_absence: "完璧じゃなくて大丈夫。\nまずは一歩だけ。",
      short_absence: "少し間が空いても大丈夫。\nまた今日から音楽を楽しみましょう。"
    }.freeze

    MESSAGE_MAP = {
      diagnosis: [
        "前回の診断から少し間が空きました。",
        "また今日から、自分のペースで歌を楽しみましょう。"
      ].freeze,
      reaction_sent: [
        "前に仲間を応援していましたね。",
        "また音楽の輪に戻ってみませんか。"
      ].freeze,
      reaction_received: [
        "仲間からの応援が届いています。",
        "また少しずつ、歌との時間を楽しみましょう。"
      ].freeze,
      challenge_progress: [
        "前に挑戦していたテーマがあります。",
        "完璧じゃなくて大丈夫。まずは一歩だけ。"
      ].freeze,
      default: [
        "ここから音楽の旅をはじめましょう。"
      ].freeze
    }.freeze

    CTA_MAP = {
      diagnosis: ["今日の診断をする", :new_singing_diagnosis_path].freeze,
      reaction_sent: ["仲間の活動を見る", "#community-feed"].freeze,
      reaction_received: ["応援を見に行く", "#encouragement-inbox"].freeze,
      challenge_progress: ["チャレンジを見る", :singing_challenges_path].freeze,
      default: ["まずは診断してみる", :new_singing_diagnosis_path].freeze
    }.freeze

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
          message: FALLBACK_MESSAGE_MAP[:long_absence],
          activity: activity
        )
      when 7..Float::INFINITY
        card(
          title: "あなたの音楽を待っています 🎤",
          message: FALLBACK_MESSAGE_MAP[:week_absence],
          activity: activity
        )
      else
        card(
          title: "おかえりなさい 🎵",
          message: FALLBACK_MESSAGE_MAP[:short_absence],
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
      message_lines = activity_source.nil? ? MESSAGE_MAP[:default] : MESSAGE_MAP[activity_source]

      message_lines.present? ? message_lines.join("\n") : fallback_message
    end

    def cta_for(activity_source)
      label, path_target = CTA_MAP.fetch(activity_source, CTA_MAP[:default])

      { label: label, path: cta_path_for(path_target) }
    end

    def cta_path_for(path_target)
      return path_target if path_target.is_a?(String)

      routes.public_send(path_target)
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
      @latest_activity ||= begin
        signal = Singing::ActivitySignalBuilder.call(@customer).latest_signal
        signal.present? ? [signal.source, signal.occurred_at] : nil
      end
    end
  end
end
