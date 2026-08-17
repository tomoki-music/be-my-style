class Song < ApplicationRecord
  MUSICAL_KEY_CANDIDATES = %w[
    C C# Db D D# Eb E F F# Gb G G# Ab A A# Bb B
    Cm C#m Dm D#m Ebm Em Fm F#m Gm G#m Am A#m Bbm Bm
  ].freeze

  belongs_to :event, inverse_of: :songs
  belongs_to :requested_by_customer, class_name: "Customer", optional: true
  has_many :song_customers, dependent: :destroy
  has_many :customers, through: :song_customers, dependent: :destroy
  has_many :join_parts, dependent: :destroy
  # source_song_idは由来記録のみに使う(テンプレートとの同期はしない)。
  # Song削除時にsong_templates.source_song_idをnullifyし、テンプレート自体は残す。
  has_many :song_templates, foreign_key: :source_song_id, dependent: :nullify, inverse_of: :source_song

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

  # requested_by_customer_idを新規設定・変更する時だけ所属チェックを行う。
  # 登録後にリクエスト者が退会・論理削除されても、他のSong属性の更新まで
  # 巻き込んで保存不能にしないため(退会後も履歴として表示し続ける方針)。
  validate :requested_by_customer_must_be_eligible_member, if: :validate_requested_by_customer_eligibility?

  before_validation :set_default_position, on: :create

  # 現役参加者が0人のパートを「募集中」とみなす。Public::EventsController#showの
  # 成立楽曲/募集中楽曲判定(join_parts.map { active_customers.length }.include?(0))と
  # 同じ基準に統一する(曲カード側で独自の募集判定基準を新設しない)。
  # 退会ユーザーだけが登録されているパートも、一般・公開画面上は「現役参加者なし」として扱う。
  # customers(preload済みならメモリ上)を見てactive_customersの新規クエリを避ける。
  def recruiting_join_parts
    join_parts.select { |join_part| join_part.customers.all?(&:is_deleted) }
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

  def validate_requested_by_customer_eligibility?
    requested_by_customer_id.present? && will_save_change_to_requested_by_customer_id?
  end

  def requested_by_customer_must_be_eligible_member
    return if event.blank? || event.community.blank?

    eligible = event.community.active_customers.exists?(id: requested_by_customer_id)
    errors.add(:requested_by_customer, "は対象コミュニティの有効なメンバーではありません") unless eligible
  end

end
