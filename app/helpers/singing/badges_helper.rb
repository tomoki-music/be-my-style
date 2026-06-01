module Singing
  module BadgesHelper
    NEW_BADGE_THRESHOLD = 7.days

    SEASONAL_RANGES = {
      "season--spring" => (3..5),
      "season--summer" => (6..8),
      "season--autumn" => (9..11)
    }.freeze

    NEAR_COMPLETION_CTA = {
      streak:    "明日も診断する →",
      score:     "スコアに挑む →",
      milestone: "診断を続ける →",
      growth:    "成長を続ける →"
    }.freeze

    ACHIEVEMENT_GROWTH_STORIES = {
      "first_diagnosis" => "あなたは最初の一歩を踏み出しました。",
      "personal_best"   => "あなたは自分の限界を、自分で更新しました。",
      "streak_7"        => "あなたは7日間、毎日歌い続けました。",
      "streak_30"       => "あなたは30日間、歌うことを習慣にしました。",
      "first_score_90"  => "あなたは90点という高みに初めて到達しました。",
      "first_ranking"   => "あなたはランキングという舞台に初めて立ちました。",
      "diagnosis_10"    => "あなたは10回、自分の声と向き合いました。",
      "growth_10"       => "あなたのスコアは10点以上、確かに伸びました。"
    }.freeze

    # earned badge → 次に自然につながるバッジ（progression chain）
    BADGE_PROGRESSION = {
      "first_diagnosis" => "diagnosis_10",
      "streak_7"        => "streak_30"
    }.freeze

    def singing_badge_label(badge)
      badge.label
    end

    def singing_badge_emoji(badge)
      badge.emoji
    end

    def singing_badge_display_text(badge)
      badge.display_text
    end

    def singing_badge_season_name(badge)
      badge.singing_ranking_season&.name
    end

    def singing_badge_new?(badge)
      badge.awarded_at >= NEW_BADGE_THRESHOLD.ago
    end

    def achievement_seasonal_class
      month = Date.today.month
      SEASONAL_RANGES.find { |_, range| range.include?(month) }&.first || "season--winter"
    end

    def near_completion_cta_label(badge_key)
      defn = SingingAchievementBadge::BADGE_DEFINITIONS[badge_key.to_s] || {}
      NEAR_COMPLETION_CTA[defn[:category]] || "診断する →"
    end

    def achievement_growth_story(badge_key)
      ACHIEVEMENT_GROWTH_STORIES[badge_key.to_s] || ""
    end

    def badge_progression_next_key(badge_key)
      BADGE_PROGRESSION[badge_key.to_s]
    end

    def badge_earned_relative_time(earned_at)
      days_ago = ((Time.current - earned_at) / 1.day).to_i
      return "今日" if days_ago.zero?
      return "#{days_ago}日前" if days_ago < 7

      earned_at.strftime("%-m月%-d日")
    end

    SCENE_TYPE_LABELS = {
      hero:              "オープニング",
      first_achievement: "最初の達成",
      growth:            "成長の記録",
      monthly_peak:      "最高潮の月",
      legendary:         "Legendary",
      ending:            "エンディング"
    }.freeze

    EMOTION_LABELS = {
      emotional: "感動的",
      hopeful:   "希望",
      powerful:  "力強い",
      nostalgic: "懐かしい"
    }.freeze

    BG_STYLE_LABELS = {
      cosmic:     "Cosmic",
      sunrise:    "Sunrise",
      neon:       "Neon",
      aurora:     "Aurora",
      dark_stage: "Dark Stage"
    }.freeze

    def scene_type_label(type)
      SCENE_TYPE_LABELS[type.to_sym] || type.to_s
    end

    def emotion_label(emotion)
      EMOTION_LABELS[emotion.to_sym] || emotion.to_s
    end

    def bg_style_label(bg_style)
      BG_STYLE_LABELS[bg_style.to_sym] || bg_style.to_s
    end

    GROWTH_CIRCLE_CONDITIONS = {
      community_supporter:  "仲間に3回以上応援リアクションを送ると獲得できます",
      growth_inspirer:      "3人以上から応援リアクションを受け取ると獲得できます",
      motivation_booster:   "3人以上の異なるユーザーに応援リアクションを送ると獲得できます",
      consistency_champion: "診断を7日連続で続けると獲得できます",
      rising_singer:        "直近5回の診断で3点以上スコアが伸びると獲得できます"
    }.freeze

    def growth_circle_condition_text(key)
      GROWTH_CIRCLE_CONDITIONS[key.to_sym] || ""
    end

    def achievement_badge_modal_data(key:, definition:, earned:, progress_hint:, can_share:, show_pin:, earned_achievement_keys: nil)
      is_earned  = earned.present?
      is_pinned  = is_earned && earned.pinned?
      rarity     = definition[:rarity]

      next_key     = badge_progression_next_key(key)
      next_def     = next_key ? SingingAchievementBadge::BADGE_DEFINITIONS[next_key.to_s] : nil
      next_earned  = next_key ? earned_achievement_keys&.include?(next_key.to_s) : false
      next_badge   = next_def ? { key: next_key, label: next_def[:label], emoji: next_def[:emoji], rarity: next_def[:rarity].to_s, earned: next_earned } : nil

      {
        key:               key,
        label:             definition[:label],
        emoji:             definition[:emoji],
        rarity:            rarity.to_s,
        category:          definition[:category].to_s,
        description:       definition[:description],
        locked_description: definition[:locked_description],
        earned:            is_earned,
        earned_at_label:   (earned.earned_at.strftime("%-m月%-d日 達成") if is_earned),
        growth_story:      (achievement_growth_story(key) if is_earned),
        progress_ratio:    (progress_hint&.progress_ratio.to_f || 0.0),
        hint_text:         (progress_hint&.progress_ratio.to_f.to_f >= 0.5 ? progress_hint&.hint_text : nil),
        detail_text:       (progress_hint&.progress_ratio.to_f.to_f >= 0.5 ? progress_hint&.detail_text : nil),
        badge_id:          (earned.id if is_earned),
        pinned:            is_pinned,
        pin_url:           (pin_singing_badge_path(earned) if is_earned),
        unpin_url:         (unpin_singing_badge_path(earned) if is_earned),
        can_share:         can_share,
        show_pin:          show_pin,
        share_url:         (singing_share_image_path(target: "achievement-badge") if is_earned && can_share),
        cta_label:         near_completion_cta_label(key),
        diagnose_url:      new_singing_diagnosis_path,
        next_badge:        next_badge
      }
    end
  end
end
