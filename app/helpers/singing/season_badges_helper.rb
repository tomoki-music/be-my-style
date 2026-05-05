module Singing::SeasonBadgesHelper
  SEASON_BADGE_LABELS = {
    "monthly_overall_top_1" => "月間トップシンガー",
    "monthly_overall_top_3" => "月間TOP3",
    "monthly_overall_top_10" => "月間TOP10",
    "monthly_pitch_top_1" => "Pitchリーダー",
    "monthly_pitch_top_3" => "Pitch TOP3",
    "monthly_rhythm_top_1" => "Rhythmリーダー",
    "monthly_rhythm_top_3" => "Rhythm TOP3",
    "monthly_expression_top_1" => "Expressionリーダー",
    "monthly_expression_top_3" => "Expression TOP3"
  }.freeze

  SEASON_BADGE_EMOJIS = {
    "monthly_overall_top_1" => "🏆",
    "monthly_overall_top_3" => "🥇",
    "monthly_overall_top_10" => "🏅",
    "monthly_pitch_top_1" => "🎯",
    "monthly_pitch_top_3" => "🎯",
    "monthly_rhythm_top_1" => "🥁",
    "monthly_rhythm_top_3" => "🥁",
    "monthly_expression_top_1" => "🎭",
    "monthly_expression_top_3" => "🎭"
  }.freeze

  SEASON_CATEGORY_LABELS = {
    "overall" => "総合ランキング",
    "pitch" => "音程ランキング",
    "rhythm" => "リズムランキング",
    "expression" => "表現力ランキング",
    "growth" => "成長ランキング"
  }.freeze

  def season_badge_label(badge_key, title: nil)
    SEASON_BADGE_LABELS[badge_key].presence || title.presence
  end

  def season_badge_emoji(badge_key)
    SEASON_BADGE_EMOJIS[badge_key]
  end

  def season_category_label(category)
    SEASON_CATEGORY_LABELS[category] || category.to_s
  end

  def season_badge_text(entry)
    label = season_badge_label(entry.badge_key, title: entry.title)
    return nil if label.blank?

    emoji = season_badge_emoji(entry.badge_key)
    [emoji, label].compact.join(" ")
  end
end
