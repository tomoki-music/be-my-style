class SingingAchievementBadge < ApplicationRecord
  BADGE_DEFINITIONS = {
    "first_diagnosis" => {
      label:              "First Note",
      short_label:        "First",
      emoji:              "🎤",
      rarity:             :common,
      category:           :milestone,
      plan:               :all,
      share_image_plan:   :core,
      description:        "初めての診断を完了しました",
      locked_description: "初めて診断を完了すると獲得できます",
      share_text:         "🎤 BeMyStyle Singing で初めての診断を完了しました！歌声診断、はじめました。 #BeMyStyle #Singing"
    }.freeze,

    "personal_best" => {
      label:              "Personal Best",
      short_label:        "PB",
      emoji:              "🥇",
      rarity:             :common,
      category:           :score,
      plan:               :all,
      share_image_plan:   :core,
      description:        "自己最高スコアを更新しました",
      locked_description: "診断で自己最高スコアを更新すると獲得できます",
      share_text:         "🥇 自己最高スコアを更新しました！継続は力なり。 #BeMyStyle #Singing #自己ベスト"
    }.freeze,

    "streak_7" => {
      label:              "7 Day Streak",
      short_label:        "Week",
      emoji:              "🔥",
      rarity:             :rare,
      category:           :streak,
      plan:               :all,
      share_image_plan:   :core,
      description:        "7日間連続で診断を行いました",
      locked_description: "7日連続で診断を行うと獲得できます",
      share_text:         "🔥 7日間連続で歌い続けました！BeMyStyle Singing で習慣化を達成。 #BeMyStyle #Singing #7日連続"
    }.freeze,

    "streak_30" => {
      label:              "Monthly Devotee",
      short_label:        "30-Day",
      emoji:              "🌟",
      rarity:             :epic,
      category:           :streak,
      plan:               :all,
      share_image_plan:   :core,
      description:        "30日間連続で診断を行いました",
      locked_description: "30日連続で診断を行うと獲得できます",
      share_text:         "🌟 30日間連続達成！毎日歌うことを習慣にできました。 #BeMyStyle #Singing #30日チャレンジ"
    }.freeze,

    "first_score_90" => {
      label:              "Score 90 Club",
      short_label:        "90+",
      emoji:              "⭐",
      rarity:             :rare,
      category:           :score,
      plan:               :all,
      share_image_plan:   :core,
      description:        "初めて90点以上を獲得しました",
      locked_description: "診断で90点以上を出すと獲得できます",
      share_text:         "⭐ ついに90点越えました！BeMyStyle Singing で目標達成。 #BeMyStyle #Singing #90点"
    }.freeze,

    "first_ranking" => {
      label:              "First Entry",
      short_label:        "Entry",
      emoji:              "🏅",
      rarity:             :common,
      category:           :ranking,
      plan:               :all,
      share_image_plan:   :core,
      description:        "初めてランキングに参加しました",
      locked_description: "診断でランキングに参加すると獲得できます",
      share_text:         "🏅 BeMyStyle Singing のランキングに初参加しました！一緒に歌いませんか？ #BeMyStyle #Singing"
    }.freeze,

    "diagnosis_10" => {
      label:              "10 Songs",
      short_label:        "10回",
      emoji:              "🎸",
      rarity:             :common,
      category:           :milestone,
      plan:               :all,
      share_image_plan:   :core,
      description:        "累計10回の診断を完了しました",
      locked_description: "診断を累計10回完了すると獲得できます",
      share_text:         "🎸 BeMyStyle Singing で累計10回の診断を完了しました！歌い続けています。 #BeMyStyle #Singing"
    }.freeze,

    "growth_10" => {
      label:              "Rising Star",
      short_label:        "Rising",
      emoji:              "📈",
      rarity:             :rare,
      category:           :growth,
      plan:               :all,
      share_image_plan:   :core,
      description:        "初回診断からスコアが10点以上アップしました",
      locked_description: "初回診断からスコアが10点以上上がると獲得できます",
      share_text:         "📈 初回診断からスコアが10点以上アップしました！継続の成果を実感中。 #BeMyStyle #Singing #上達中"
    }.freeze
  }.freeze

  MVP_BADGE_KEYS = BADGE_DEFINITIONS.keys.freeze

  RARITIES = %i[common rare epic legendary].freeze

  CATEGORIES = %i[milestone streak score growth ranking skill challenge special].freeze

  RARITY_ORDER = %i[legendary epic rare common].freeze

  CATEGORY_ORDER = %i[milestone streak score growth ranking skill challenge special].freeze

  belongs_to :customer
  belongs_to :singing_diagnosis, optional: true

  validates :badge_key, presence: true,
                        inclusion: { in: BADGE_DEFINITIONS.keys }
  validates :earned_at, presence: true

  scope :earned,        -> { order(earned_at: :desc) }
  scope :for_category,  ->(cat) { where("JSON_EXTRACT(metadata, '$.category') = ?", cat.to_s) }
  scope :by_rarity,     -> { sort_by { |b| RARITY_ORDER.index(definition(b.badge_key)[:rarity]) || 99 } }

  def self.definition(badge_key)
    BADGE_DEFINITIONS[badge_key.to_s] || {}
  end

  def definition
    self.class.definition(badge_key)
  end

  def label        = definition[:label]
  def short_label  = definition[:short_label]
  def emoji        = definition[:emoji]
  def rarity       = definition[:rarity]
  def category     = definition[:category]
  def description  = definition[:description]
  def share_text   = definition[:share_text]
end
