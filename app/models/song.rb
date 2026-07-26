class Song < ApplicationRecord
  MUSICAL_KEY_CANDIDATES = %w[
    C C# Db D D# Eb E F F# Gb G G# Ab A A# Bb B
    Cm C#m Dm D#m Ebm Em Fm F#m Gm G#m Am A#m Bbm Bm
  ].freeze

  belongs_to :event, inverse_of: :songs
  has_many :song_customers, dependent: :destroy
  has_many :customers, through: :song_customers, dependent: :destroy
  has_many :join_parts, dependent: :destroy

  accepts_nested_attributes_for :join_parts, allow_destroy: true, reject_if: :all_blank

  with_options presence: true do
    validates :song_name
  end

  validates :performance_time,
            format: {
              with: /\A\d{1,2}:\d{2}\z/,
              message: "は MM:SS 形式で入力してください"
            },
            allow_blank: true
  validates :performance_start_time,
            format: {
              with: /\A\d{1,2}:\d{2}\z/,
              message: "は HH:MM 形式で入力してください"
            },
            allow_blank: true
  validates :chord_sheet_url,
            length: { maximum: 2048 },
            allow_blank: true
  validates :musical_key,
            length: { maximum: 100 },
            allow_blank: true
  validates :capo,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 12
            },
            allow_nil: true
  validates :chord_sheet_note,
            length: { maximum: 300 },
            allow_blank: true
  validates :tab_sheet_url,
            length: { maximum: 2048 },
            allow_blank: true

  before_validation :set_default_position, on: :create

  # 参加者が0人のパートを「募集中」とみなす。Public::EventsController#showの
  # 成立楽曲/募集中楽曲判定(join_parts.map { customers.length }.include?(0))と
  # 同じ基準に統一する(曲カード側で独自の募集判定基準を新設しない)。
  def recruiting_join_parts
    join_parts.select { |join_part| join_part.customers.empty? }
  end

  def capo_label
    return nil if capo.nil?
    return "なし" if capo.zero?

    capo.to_s
  end

  private

  def set_default_position
    self.position ||= (event.songs.maximum(:position) || 0) + 1 if event.present?
  end

end
