module Singing
  class CommunityMemoryBuilder
    Result = Struct.new(
      :active,
      :icon,
      :title,
      :message,
      :cta_label,
      :cta_path,
      :activity_source,
      :latest_activity_at,
      keyword_init: true
    ) do
      def active?
        active == true
      end
    end

    MEMORY_TYPES = {
      diagnosis: {
        icon: "🎤",
        title: "前回は歌唱診断を完了しました",
        message: "前回の成長を振り返ってみましょう。",
        cta_label: "診断履歴を見る",
        cta_path: :singing_diagnoses_path
      },
      reaction_sent: {
        icon: "🔥",
        title: "前回は仲間を応援しました",
        message: "応援はコミュニティを育てます。",
        cta_label: "仲間の活動を見る",
        cta_path: "#community-feed"
      },
      reaction_received: {
        icon: "👏",
        title: "前回あなたの活動に応援が届きました",
        message: "応援を受け取ってみましょう。",
        cta_label: "応援を見る",
        cta_path: "#encouragement-inbox"
      },
      challenge_progress: {
        icon: "🏆",
        title: "チャレンジ継続中です",
        message: "達成まであと少しです。",
        cta_label: "チャレンジを見る",
        cta_path: :singing_challenges_path
      },
      journey: {
        icon: "🎵",
        title: "音楽の旅を続けています",
        message: "少しずつ積み重ねています。",
        cta_label: "成長履歴を見る",
        cta_path: :singing_diagnoses_path
      }
    }.freeze

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return inactive if @customer.nil?

      source, occurred_at = prioritized_memory
      return inactive if source.nil?

      build_result(source, occurred_at)
    end

    private

    def prioritized_memory
      [
        [:diagnosis, latest_completed_diagnosis_at],
        [:reaction_sent, latest_profile_reaction_sent_at],
        [:reaction_received, latest_profile_reaction_received_at],
        [:challenge_progress, latest_challenge_progress_at],
        [:journey, journey_activity_at]
      ].find { |(_, occurred_at)| occurred_at.present? }
    end

    def build_result(source, occurred_at)
      memory = MEMORY_TYPES.fetch(source)

      Result.new(
        active: true,
        icon: memory[:icon],
        title: memory[:title],
        message: memory[:message],
        cta_label: memory[:cta_label],
        cta_path: cta_path_for(memory[:cta_path]),
        activity_source: source,
        latest_activity_at: occurred_at
      )
    end

    def inactive
      Result.new(
        active: false,
        icon: nil,
        title: nil,
        message: nil,
        cta_label: nil,
        cta_path: nil,
        activity_source: nil,
        latest_activity_at: nil
      )
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

      SingingAiChallengeProgress
        .where(customer: @customer)
        .where(completed: false)
        .maximum(:updated_at)
    rescue NameError, NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def journey_activity_at
      summary = Singing::JourneySummaryBuilder.call(@customer)
      return nil unless summary&.has_diagnoses

      SingingDiagnosis.completed.where(customer: @customer).maximum(:created_at)
    rescue NameError, NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def cta_path_for(path_target)
      return path_target if path_target.is_a?(String)

      Rails.application.routes.url_helpers.public_send(path_target)
    end
  end
end
