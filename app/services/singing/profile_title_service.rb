module Singing
  class ProfileTitleService
    Title = Struct.new(:key, :label, :description, :icon, keyword_init: true)

    TITLE_DEFINITIONS = [
      {
        key: :monthly_champion,
        label: "今月の王者",
        description: "シーズン1位に輝いたトップシンガー",
        icon: "🥇"
      },
      {
        key: :monthly_runner_up,
        label: "準優勝シンガー",
        description: "シーズン2位に輝いた実力者",
        icon: "🥈"
      },
      {
        key: :monthly_top_3,
        label: "TOP3シンガー",
        description: "シーズントップ3入りを果たした実力者",
        icon: "🥉"
      },
      {
        key: :monthly_top_10,
        label: "TOP10シンガー",
        description: "シーズントップ10に入った実力者",
        icon: "🎯"
      },
      {
        key: :season_participant,
        label: "継続チャレンジャー",
        description: "シーズンに参加して挑戦を積み上げた証",
        icon: "🔥"
      },
      {
        key: :season_1st,
        label: "今月の王者",
        description: "シーズン1位に輝いたトップシンガー",
        icon: "🥇"
      },
      {
        key: :season_2nd,
        label: "準優勝シンガー",
        description: "シーズン2位に輝いた実力者",
        icon: "🥈"
      },
      {
        key: :season_top3,
        label: "TOP3シンガー",
        description: "シーズントップ3入りを果たした実力者",
        icon: "🥉"
      },
      {
        key: :season_top10,
        label: "TOP10シンガー",
        description: "シーズントップ10に入った実力者",
        icon: "🎯"
      },
      {
        key: :rapid_growth,
        label: "急成長シンガー",
        description: "成長ランキングTOP3に輝いた証",
        icon: "📈"
      },
      {
        key: :consecutive_participation,
        label: "継続チャレンジャー",
        description: "コツコツ続けることで積み上げた証",
        icon: "🔥"
      }
    ].freeze

    BADGE_COLLECTOR_THRESHOLD = 3

    BADGE_COLLECTOR_TITLE = Title.new(
      key: :badge_collector,
      label: "バッジコレクター",
      description: "複数のバッジを集めた証",
      icon: "🎖️"
    ).freeze

    CHALLENGER_TITLE = Title.new(
      key: :challenger,
      label: "挑戦者",
      description: "記録への第一歩を踏み出そう",
      icon: "🎵"
    ).freeze

    def self.call(season_badges)
      new(season_badges).call
    end

    def initialize(season_badges)
      @season_badges = season_badges
    end

    def call
      badge_types = @season_badges.map(&:badge_type)

      TITLE_DEFINITIONS.each do |definition|
        return Title.new(**definition) if badge_types.include?(definition[:key].to_s)
      end

      return BADGE_COLLECTOR_TITLE if @season_badges.size >= BADGE_COLLECTOR_THRESHOLD

      CHALLENGER_TITLE
    end
  end
end
