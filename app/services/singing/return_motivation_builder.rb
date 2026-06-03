module Singing
  class ReturnMotivationBuilder
    ReturnMotivation = Struct.new(
      :visible,
      :title,
      :message,
      :cta_label,
      :cta_path,
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

      inactive_days = days_since_last_completed_diagnosis
      return hidden if inactive_days.present? && inactive_days < 3

      build_card(inactive_days)
    end

    private

    def build_card(inactive_days)
      case inactive_days
      when 30..Float::INFINITY
        card(
          title: "また歌いたくなったら、",
          message: "いつでも帰ってきてください 🌱"
        )
      when 7..Float::INFINITY
        card(
          title: "あなたの音楽を待っています 🎤",
          message: "完璧じゃなくて大丈夫。\nまずは一歩だけ。"
        )
      else
        card(
          title: "おかえりなさい 🎵",
          message: "少し間が空いても大丈夫。\nまた今日から音楽を楽しみましょう。"
        )
      end
    end

    def card(title:, message:)
      ReturnMotivation.new(
        visible: true,
        title: title,
        message: message,
        cta_label: "今日の診断をする",
        cta_path: Rails.application.routes.url_helpers.new_singing_diagnosis_path
      )
    end

    def hidden
      ReturnMotivation.new(
        visible: false,
        title: nil,
        message: nil,
        cta_label: nil,
        cta_path: nil
      )
    end

    def days_since_last_completed_diagnosis
      latest_at = latest_completed_diagnosis&.created_at
      return nil if latest_at.blank?

      ((Time.zone.now - latest_at) / 1.day).floor
    rescue NoMethodError
      nil
    end

    def latest_completed_diagnosis
      @latest_completed_diagnosis ||= @customer.singing_diagnoses.completed.order(created_at: :desc).first
    rescue NoMethodError
      nil
    end
  end
end
