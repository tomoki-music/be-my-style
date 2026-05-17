module Singing
  class AchievementRecapMovieBuilder
    BACKGROUND_STYLES = %i[cosmic sunrise neon aurora dark_stage].freeze
    EMOTIONS          = %i[emotional hopeful powerful nostalgic].freeze

    Result = Struct.new(
      :year,
      :title,
      :subtitle,
      :scenes,
      :total_duration,
      :empty,
      keyword_init: true
    ) do
      def empty? = empty
    end

    Scene = Struct.new(
      :type,
      :title,
      :subtitle,
      :body,
      :badge,
      :background_style,
      :duration,
      :emotion,
      :index,
      keyword_init: true
    )

    def self.call(customer, year:)
      new(customer, year: year).build
    end

    def initialize(customer, year:)
      @customer = customer
      @year     = year.to_i
    end

    def build
      rewind = Singing::YearlyAchievementRewindBuilder.call(@customer, year: @year)
      return empty_result if rewind.empty?

      raw_scenes = build_scenes(rewind)
      indexed    = raw_scenes.each_with_index.map { |s, i| s.tap { s.index = i } }

      Result.new(
        year:           @year,
        title:          "#{@year}年の軌跡",
        subtitle:       build_subtitle(rewind),
        scenes:         indexed,
        total_duration: indexed.sum(&:duration),
        empty:          false
      )
    end

    private

    def build_scenes(rewind)
      scenes = []
      scenes << hero_scene(rewind)
      scenes << first_achievement_scene(rewind) if rewind.first_earned
      scenes << growth_scene(rewind)            if rewind.total_count >= 3
      scenes << monthly_peak_scene(rewind)      if peak_month(rewind)
      scenes << legendary_scene(rewind)         if rewind.has_legendary
      scenes << ending_scene(rewind)
      scenes
    end

    def hero_scene(rewind)
      Scene.new(
        type:             :hero,
        title:            "#{@year}年、あなたの歌声の物語。",
        subtitle:         "#{rewind.total_count}件の Achievement を積み重ねた年",
        body:             "この1年間、あなたは歌い続けました。記録のひとつひとつが、あなたの成長の証です。",
        badge:            rewind.representative_badge,
        background_style: :cosmic,
        duration:         6,
        emotion:          :emotional,
        index:            0
      )
    end

    def first_achievement_scene(rewind)
      first = rewind.first_earned
      Scene.new(
        type:             :first_achievement,
        title:            "最初の一歩を踏み出した日。",
        subtitle:         first.label,
        body:             "#{first.earned_at.strftime('%-m月%-d日')}、#{first.emoji} #{first.label} を達成しました。ここから、すべてが始まりました。",
        badge:            first,
        background_style: :sunrise,
        duration:         6,
        emotion:          :hopeful,
        index:            0
      )
    end

    def growth_scene(rewind)
      Scene.new(
        type:             :growth,
        title:            "歌声は、少しずつ変わっていった。",
        subtitle:         "#{rewind.total_count}件の達成が積み重なった",
        body:             build_growth_body(rewind),
        badge:            nil,
        background_style: :aurora,
        duration:         7,
        emotion:          :hopeful,
        index:            0
      )
    end

    def monthly_peak_scene(rewind)
      peak = peak_month(rewind)
      Scene.new(
        type:             :monthly_peak,
        title:            "#{peak.month.strftime('%-m月')}、最も輝いた月。",
        subtitle:         "#{peak.total_count}件を達成",
        body:             "#{peak.month.strftime('%-m月')}はあなたの絶頂期でした。#{peak.total_count}件の Achievement を達成しました。",
        badge:            peak.representative_badge,
        background_style: :neon,
        duration:         6,
        emotion:          :powerful,
        index:            0
      )
    end

    def legendary_scene(rewind)
      first_legendary = rewind.items.select { |i| i.rarity == :legendary }.min_by(&:earned_at)
      Scene.new(
        type:             :legendary,
        title:            "Legendary に到達した。",
        subtitle:         first_legendary&.label || "Legendary Achievement",
        body:             "#{@year}年、あなたは最高レアリティ Legendary を達成しました。これはあなたの歌声の歴史に刻まれる瞬間です。",
        badge:            first_legendary,
        background_style: :dark_stage,
        duration:         8,
        emotion:          :powerful,
        index:            0
      )
    end

    def ending_scene(rewind)
      last = rewind.last_earned
      Scene.new(
        type:             :ending,
        title:            "この1年が、次の1年への土台になる。",
        subtitle:         "#{@year}年、ありがとう。",
        body:             last ? "最後の Achievement「#{last.emoji} #{last.label}」を胸に、また新しい年へ。" \
                               : "#{@year}年のすべての挑戦が、あなたの糧になっています。",
        badge:            last,
        background_style: :cosmic,
        duration:         7,
        emotion:          :nostalgic,
        index:            0
      )
    end

    def peak_month(rewind)
      @peak_month ||= rewind.monthly_highlights.reject(&:empty?).max_by(&:total_count)
    end

    def build_subtitle(rewind)
      if rewind.has_legendary
        "Legendary 達成の年"
      elsif rewind.has_epic
        "Epic 達成の年"
      else
        "#{rewind.total_count}件の Achievement"
      end
    end

    def build_growth_body(rewind)
      first = rewind.first_earned
      last  = rewind.last_earned
      if first && last && first.badge_id != last.badge_id
        "#{first.emoji} #{first.label} から始まり、#{last.emoji} #{last.label} まで。あなたの歌声は確かに前進しました。"
      else
        "#{rewind.total_count}件の Achievement が、あなたの成長の証です。"
      end
    end

    def empty_result
      Result.new(
        year:           @year,
        title:          "#{@year}年の Recap",
        subtitle:       "",
        scenes:         [],
        total_duration: 0,
        empty:          true
      )
    end
  end
end
