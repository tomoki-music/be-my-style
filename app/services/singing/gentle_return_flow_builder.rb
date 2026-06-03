module Singing
  class GentleReturnFlowBuilder
    Result = Struct.new(
      :active,
      :icon,
      :title,
      :message,
      :cta_label,
      :cta_path,
      :absence_level,
      :latest_activity_at,
      :activity_source,
      keyword_init: true
    ) do
      def active?
        active == true
      end
    end

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return inactive if @customer.nil?

      activity = latest_activity
      return inactive if activity.nil?

      source, occurred_at = activity
      build_result(days_since(occurred_at), source, occurred_at)
    end

    private

    def build_result(inactive_days, source, occurred_at)
      case inactive_days
      when 30..Float::INFINITY
        active_result(
          icon: "🌙",
          title: "おかえりなさい",
          message: "少し間が空いても大丈夫です。\n音楽は、また今日から楽しめます。",
          cta_label: "軽く歌ってみる",
          cta_path: routes.new_singing_diagnosis_path,
          absence_level: :long_absence,
          source: source,
          occurred_at: occurred_at
        )
      when 7..Float::INFINITY
        active_result(
          icon: "🎵",
          title: "また少しずつ始めましょう",
          message: "前の続きからで大丈夫です。\n今日できる小さな一歩を選びましょう。",
          cta_label: "今日の一歩を見る",
          cta_path: "#todays-mission",
          absence_level: :medium_absence,
          source: source,
          occurred_at: occurred_at
        )
      else
        inactive(latest_activity_at: occurred_at, activity_source: source)
      end
    end

    def active_result(icon:, title:, message:, cta_label:, cta_path:, absence_level:, source:, occurred_at:)
      Result.new(
        active: true,
        icon: icon,
        title: title,
        message: message,
        cta_label: cta_label,
        cta_path: cta_path,
        absence_level: absence_level,
        latest_activity_at: occurred_at,
        activity_source: source
      )
    end

    def inactive(latest_activity_at: nil, activity_source: nil)
      Result.new(
        active: false,
        icon: nil,
        title: nil,
        message: nil,
        cta_label: nil,
        cta_path: nil,
        absence_level: :none,
        latest_activity_at: latest_activity_at,
        activity_source: activity_source
      )
    end

    def latest_activity
      @latest_activity ||= activity_candidates.select { |(_, occurred_at)| occurred_at.present? }.max_by(&:last)
    end

    def activity_candidates
      [
        [:diagnosis, latest_completed_diagnosis_at],
        [:reaction_sent, latest_profile_reaction_sent_at],
        [:reaction_received, latest_profile_reaction_received_at],
        [:challenge_progress, latest_challenge_progress_at]
      ]
    end

    def latest_completed_diagnosis_at
      SingingDiagnosis.completed.where(customer: @customer).maximum(:created_at)
    rescue NameError, NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def latest_profile_reaction_sent_at
      SingingProfileReaction.where(customer: @customer).maximum(:created_at)
    rescue NameError, NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def latest_profile_reaction_received_at
      SingingProfileReaction.where(target_customer_id: @customer.id).maximum(:created_at)
    rescue NameError, NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def latest_challenge_progress_at
      return nil unless Object.const_defined?(:SingingAiChallengeProgress)

      SingingAiChallengeProgress.where(customer: @customer).maximum(:updated_at)
    rescue NameError, NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def days_since(occurred_at)
      return nil if occurred_at.blank?

      ((Time.zone.now - occurred_at) / 1.day).floor
    rescue NoMethodError, TypeError
      nil
    end

    def routes
      Rails.application.routes.url_helpers
    end
  end
end
