class VideoCaption < ApplicationRecord
  TEXT_MAX_LENGTH = 200

  belongs_to :caption_video, inverse_of: :video_captions

  # 将来のAI自動分類(メイン/サブ/強調判定の根拠・信頼度等)を保存する領域。MVPでは未使用。
  serialize :emphasis_data, JSON

  enum caption_type: {
    normal:     "normal",
    main:       "main",
    sub:        "sub",
    emphasis:   "emphasis",
    heading:    "heading",
    annotation: "annotation"
  }

  CAPTION_TYPE_LABELS = {
    "normal"     => "通常",
    "main"       => "メイン",
    "sub"        => "サブ",
    "emphasis"   => "強調",
    "heading"    => "見出し",
    "annotation" => "注釈"
  }.freeze

  # MVPでは "bottom_center" のみ。将来の配置バリエーション追加に備え、
  # Rails enum ではなく単純な許可リストで持つ(値追加のたびに enum のメソッド名衝突を気にしなくて済む)。
  POSITIONS = %w[bottom_center].freeze

  validates :text, presence: true, length: { maximum: TEXT_MAX_LENGTH }
  validates :caption_type, presence: true
  validates :position, presence: true, inclusion: { in: POSITIONS }
  validates :display_order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :start_time, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :end_time, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :end_time_after_start_time
  validate :within_video_duration

  scope :ordered, -> { order(:display_order, :id) }

  def duration
    return nil if start_time.nil? || end_time.nil?

    end_time - start_time
  end

  private

  def end_time_after_start_time
    return if start_time.nil? || end_time.nil?

    errors.add(:end_time, "は開始時間より後にしてください") if end_time <= start_time
  end

  def within_video_duration
    return if end_time.nil?
    return if caption_video.nil? || caption_video.duration.nil?

    if end_time > caption_video.duration
      errors.add(:end_time, "は動画の長さを超えられません")
    end
  end
end
