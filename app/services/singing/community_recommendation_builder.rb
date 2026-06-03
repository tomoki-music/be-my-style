module Singing
  class CommunityRecommendationBuilder
    Result = Struct.new(
      :active,
      :icon,
      :title,
      :message,
      :cta_label,
      :cta_path,
      keyword_init: true
    ) do
      def active?
        active == true
      end
    end

    RECOMMENDATIONS = {
      diagnosis: {
        icon: "🎤",
        title: "次は仲間の活動も見てみましょう",
        message: "音楽は一人でも楽しめますが、\n仲間とつながるともっと楽しくなります。",
        cta_label: "Community Feedを見る",
        cta_path: :singing_growth_feed_path
      },
      reaction_sent: {
        icon: "🔥",
        title: "応援ありがとうございます",
        message: "今度は自分の成長も記録してみましょう。",
        cta_label: "歌唱診断をする",
        cta_path: :new_singing_diagnosis_path
      },
      reaction_received: {
        icon: "👏",
        title: "仲間から応援が届いています",
        message: "その勢いで次の挑戦に進みましょう。",
        cta_label: "チャレンジを見る",
        cta_path: :singing_challenges_path
      },
      challenge_progress: {
        icon: "🏆",
        title: "あと少しで達成です",
        message: "継続は大きな成長につながります。",
        cta_label: "Challengeを見る",
        cta_path: :singing_challenges_path
      },
      fallback: {
        icon: "🎵",
        title: "今日も音楽を楽しみましょう",
        message: "小さな一歩から始まります。",
        cta_label: "歌唱診断をする",
        cta_path: :new_singing_diagnosis_path
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

      source = latest_activity_source || :fallback
      build_result(source)
    end

    private

    def latest_activity_source
      activity_signals.signals.find { |signal| recommendation_signal?(signal) }&.source
    end

    def build_result(source)
      recommendation = RECOMMENDATIONS.fetch(source)

      Result.new(
        active: true,
        icon: recommendation[:icon],
        title: recommendation[:title],
        message: recommendation[:message],
        cta_label: recommendation[:cta_label],
        cta_path: cta_path_for(recommendation[:cta_path])
      )
    end

    def inactive
      Result.new(
        active: false,
        icon: nil,
        title: nil,
        message: nil,
        cta_label: nil,
        cta_path: nil
      )
    end

    def activity_signals
      @activity_signals ||= Singing::ActivitySignalBuilder.call(@customer)
    end

    def recommendation_signal?(signal)
      return false if signal.source == :challenge_progress && signal.metadata.to_h[:completed] == true

      true
    end

    def cta_path_for(path_target)
      Rails.application.routes.url_helpers.public_send(path_target)
    end
  end
end
