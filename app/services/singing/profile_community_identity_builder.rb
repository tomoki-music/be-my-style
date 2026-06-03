module Singing
  class ProfileCommunityIdentityBuilder
    ACTIVITY_SUMMARIES = {
      cheer:     "仲間への応援が広がっています",
      challenge: "挑戦を重ねながら成長しています",
      streak:    "コツコツ歌を楽しんでいます",
      default:   "音楽の輪に参加しています"
    }.freeze

    IDENTITY_MESSAGES = {
      consistency_hero: "コツコツ続けながら、自分らしい歌を育てています。",
      cheer:            "仲間を応援しながら、音楽の輪を広げています。",
      challenger:       "挑戦を続けながら、自分らしい歌を育てています。",
      default:          "自分のペースで歌を楽しむメンバーです。"
    }.freeze

    MISSION_LABELS_BY_GROWTH_TYPE = {
      consistency_hero:  "継続を楽しむ",
      emotional_singer:  "表現力を育てる",
      voice_challenger:  "音程に挑戦する",
      rhythm_explorer:   "リズムを探求する",
      dynamic_performer: "バランスよく磨く",
      groove_builder:    "自分スタイルを見つける"
    }.freeze

    PERFORMER_LEVELS = %i[performer community_star music_partner music_ambassador].freeze

    ProfileCommunityIdentity = Struct.new(
      :reputation_title,
      :reputation_points,
      :growth_type_label,
      :growth_circle_name,
      :mission_label,
      :activity_summary,
      :identity_message,
      keyword_init: true
    )

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return nil if @customer.nil?

      ProfileCommunityIdentity.new(
        reputation_title:   reputation&.reputation_title,
        reputation_points:  reputation&.reputation_points.to_i,
        growth_type_label:  growth_type&.label,
        growth_circle_name: primary_circle&.title,
        mission_label:      mission_label,
        activity_summary:   activity_summary,
        identity_message:   identity_message
      )
    end

    private

    def reputation
      @reputation ||= Singing::CommunityReputationBuilder.call(customer: @customer)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      nil
    end

    def growth_type
      @growth_type ||= Singing::GrowthTypeAnalyzer.call(@customer)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      nil
    end

    def circles
      @circles ||= Singing::GrowthCirclesBuilder.call(@customer)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      []
    end

    def primary_circle
      circles.first
    end

    def latest_diagnosis
      @latest_diagnosis ||= @customer
        .singing_diagnoses
        .completed
        .order(created_at: :desc, id: :desc)
        .first
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      nil
    end

    def mission_label
      return latest_diagnosis.next_mission_title if latest_diagnosis&.next_mission_title.present?

      MISSION_LABELS_BY_GROWTH_TYPE[growth_type&.type_key] || MISSION_LABELS_BY_GROWTH_TYPE[:groove_builder]
    end

    def activity_summary
      return ACTIVITY_SUMMARIES[:cheer]     if cheer_active?
      return ACTIVITY_SUMMARIES[:challenge]  if PERFORMER_LEVELS.include?(reputation&.reputation_level)
      return ACTIVITY_SUMMARIES[:streak]    if reputation&.streak_points.to_i >= 3

      ACTIVITY_SUMMARIES[:default]
    end

    def identity_message
      return IDENTITY_MESSAGES[:consistency_hero] if growth_type&.type_key == :consistency_hero
      return IDENTITY_MESSAGES[:cheer]            if cheer_active?
      return IDENTITY_MESSAGES[:challenger]       if challenger_type?

      IDENTITY_MESSAGES[:default]
    end

    def cheer_active?
      reputation&.cheer_points.to_i > 0
    end

    def challenger_type?
      %i[voice_challenger dynamic_performer].include?(growth_type&.type_key)
    end
  end
end
