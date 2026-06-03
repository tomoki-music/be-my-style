module Singing
  class MusicCommunityHomeBuilder
    MusicCommunityHome = Struct.new(
      :hero_message,
      :home_cta,
      :today_mission,
      :return_motivation,
      :community_network,
      :suggested_musicians,
      :growth_circles,
      :ecosystem,
      :reputation,
      :growth_partnerships,
      :music_social_graph,
      :community_summary,
      :recommended_event,
      :growth_summary,
      keyword_init: true
    )

    HomeCta = Struct.new(
      :primary_label,
      :primary_path,
      :secondary_label,
      :secondary_path,
      :message,
      keyword_init: true
    )

    Summary = Struct.new(
      :title,
      :message,
      :items,
      :cta_label,
      :cta_url,
      keyword_init: true
    )

    Item = Struct.new(
      :label,
      :title,
      :message,
      :meta,
      keyword_init: true
    )

    def self.call(customer, challenge_experience: nil)
      new(customer, challenge_experience: challenge_experience).call
    end

    def initialize(customer, challenge_experience: nil)
      @customer = customer
      @challenge_experience = challenge_experience
    end

    def call
      experience = @challenge_experience || Singing::ChallengeExperienceBuilder.call(@customer)

      MusicCommunityHome.new(
        hero_message: hero_message,
        home_cta: home_cta,
        today_mission: experience.todays_mission,
        return_motivation: Singing::ReturnMotivationBuilder.call(@customer),
        community_network: Singing::CommunityNetworkBuilder.call(@customer),
        suggested_musicians: Singing::SuggestedMusiciansBuilder.call(@customer, current_customer: @customer),
        growth_circles: Singing::GrowthCirclesBuilder.call(@customer),
        ecosystem: Singing::MusicCommunityEcosystemBuilder.call(customer: @customer),
        reputation: Singing::CommunityReputationBuilder.call(customer: @customer),
        growth_partnerships: Singing::GrowthPartnershipsBuilder.call(customer: @customer),
        music_social_graph: Singing::MusicSocialGraphBuilder.call(customer: @customer),
        community_summary: community_summary(experience),
        recommended_event: recommended_event(experience),
        growth_summary: growth_summary(experience)
      )
    end

    private

    def home_cta
      if @customer.nil?
        HomeCta.new(
          primary_label: "無料で始める",
          primary_path: "/customers/sign_up",
          secondary_label: "コミュニティを見る",
          secondary_path: "/public/communities/7",
          message: "あなたの歌は、ここから少しずつ育っていきます。今日の一歩を、音楽の輪につなげましょう。"
        )
      elsif diagnosis_count.zero?
        HomeCta.new(
          primary_label: "最初の診断をする",
          primary_path: "/singing/diagnoses/new",
          secondary_label: "コミュニティを見る",
          secondary_path: "/public/communities/7",
          message: "まずは一度、今の声を残してみよう。記録が、あなたの音楽の出発点になります。"
        )
      elsif diagnosis_count >= 3
        HomeCta.new(
          primary_label: "成長レポートを見る",
          primary_path: "/singing/diagnoses",
          secondary_label: "イベントを見る",
          secondary_path: "/public/events",
          message: "あなたの歌は、ここから少しずつ育っています。今日の一歩を、音楽の輪につなげましょう。"
        )
      else
        HomeCta.new(
          primary_label: "今日のミッションを見る",
          primary_path: "/singing/challenges",
          secondary_label: "診断する",
          secondary_path: "/singing/diagnoses/new",
          message: "あなたの歌は、ここから少しずつ育っていきます。今日の一歩を、音楽の輪につなげましょう。"
        )
      end
    end

    def hero_message
      if diagnosis_count.zero?
        "最初の一歩を踏み出そう"
      else
        "今日も少しずつ成長しています"
      end
    end

    def community_summary(experience)
      matching = experience.mission_matching
      challenge = experience.community_challenge
      growth_community = experience.growth_type_community

      Summary.new(
        title: "仲間とつながる",
        message: "同じように歌を楽しみながら成長している仲間がいます。",
        items: [
          Item.new(
            label: "Mission Matching",
            title: matching&.title || "同じ方向へ挑戦する仲間がいます",
            message: matching&.message || "今日の一歩を、ひとりで抱えなくて大丈夫です。",
            meta: "#{matching&.matched_count.to_i}人が近いテーマに挑戦中"
          ),
          Item.new(
            label: "Community Challenge",
            title: challenge&.title || "Community Challenge",
            message: challenge&.message || "あなたの一歩が、次の挑戦者を生み出します。",
            meta: "参加 #{challenge&.participant_count.to_i} / 応援 #{challenge&.cheer_count.to_i}"
          ),
          Item.new(
            label: growth_community&.description || "Growth Community",
            title: growth_community&.title || "あなたらしい成長を見つける仲間がいます",
            message: growth_community&.community_message || "歌い方に正解はありません。楽しみながら見つけていきましょう。",
            meta: "#{growth_community&.member_count.to_i}人の仲間"
          )
        ],
        cta_label: matching&.cta_label || growth_community&.cta_label || "コミュニティを見る",
        cta_url: matching&.cta_url || growth_community&.cta_url || "/public/communities/7"
      )
    end

    def recommended_event(experience)
      session = experience.session_recommendation
      connection = experience.mmm_connection

      Summary.new(
        title: "音楽の場へ出会う",
        message: "今日の挑戦は、セッションやイベントにもゆるやかにつながります。",
        items: [
          Item.new(
            label: "Session Recommendation",
            title: session&.event_name || "音楽コミュニティイベント",
            message: session&.message || "歌う場所を知るだけでも、次の一歩が軽くなります。",
            meta: session&.reason
          ),
          Item.new(
            label: "MMM Connection",
            title: connection&.title || "音楽を楽しむ仲間がいます",
            message: connection&.message || "今日の小さな挑戦を、外の音楽体験へ広げていこう。",
            meta: connection_meta(connection)
          )
        ],
        cta_label: session&.cta_label || connection&.cta_label || "イベントを見る",
        cta_url: session&.event_url || connection&.cta_url || "/public/events"
      )
    end

    def growth_summary(experience)
      journey = experience.recommended_journey
      roadmap = experience.personal_growth_roadmap
      current_step = roadmap&.steps&.find { |step| step.status == :current } || roadmap&.steps&.first

      Summary.new(
        title: "成長をやさしく続ける",
        message: roadmap&.coach_message || "歌う回数が増えるほど、自分の声と仲良くなっていきます。",
        items: [
          Item.new(
            label: "Recommended Journey",
            title: journey&.title || "好きな曲で挑戦を続けよう",
            message: journey&.message || "楽しめる曲を選ぶことが、継続の一番近い入口です。",
            meta: journey&.action_label || "この挑戦を始める"
          ),
          Item.new(
            label: current_step&.label || "STEP 1",
            title: current_step&.title || "今月の声を残す",
            message: current_step&.description || "上手さより、今日の声を記録することから始めよう。",
            meta: roadmap&.title || "Personal Growth Roadmap"
          )
        ],
        cta_label: "成長記録を見る",
        cta_url: "/singing/diagnoses"
      )
    end

    def diagnosis_count
      return 0 if @customer.nil?

      @diagnosis_count ||= @customer.singing_diagnoses.completed.count
    rescue NoMethodError
      0
    end

    def connection_meta(connection)
      case connection&.connection_type
      when :event
        "イベントにつながる"
      when :community
        "コミュニティにつながる"
      when :growth_type
        "仲間探しにつながる"
      when :challenge
        "挑戦テーマにつながる"
      else
        "音楽体験につながる"
      end
    end
  end
end
