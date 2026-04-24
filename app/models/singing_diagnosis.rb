class SingingDiagnosis < ApplicationRecord
  attr_accessor :reference_key, :reference_bpm

  belongs_to :customer

  has_one_attached :audio_file

  serialize :result_payload, JSON

  enum status: {
    queued: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  enum performance_type: {
    vocal: 0,
    guitar: 1,
    bass: 2,
    drums: 3,
    keyboard: 4,
    band: 5
  }, _prefix: true

  enum ai_comment_status: {
    ai_comment_not_requested: 0,
    ai_comment_queued: 1,
    ai_comment_processing: 2,
    ai_comment_completed: 3,
    ai_comment_failed: 4
  }

  validates :status, presence: true
  validates :performance_type, presence: true
  validates :ai_comment_status, presence: true
  validates :song_title, length: { maximum: 100 }, allow_blank: true
  validates :ai_comment, length: { maximum: 2000 }, allow_blank: true
  validates :overall_score, :pitch_score, :rhythm_score, :expression_score,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true
  validate :audio_file_attached

  SCORE_ATTRIBUTES = %i[
    overall_score
    pitch_score
    rhythm_score
    expression_score
  ].freeze

  PERFORMANCE_TYPE_LABELS = {
    "vocal" => "ボーカル",
    "guitar" => "ギター",
    "bass" => "ベース",
    "drums" => "ドラム",
    "keyboard" => "キーボード",
    "band" => "バンド演奏"
  }.freeze

  FUTURE_PERFORMANCE_TYPE_LABELS = PERFORMANCE_TYPE_LABELS.reject { |key, _| key == "vocal" }.freeze

  def self.performance_type_options
    [
      ["ボーカル", "vocal"],
      ["ギター", "guitar"],
      ["ベース", "bass"],
      ["ドラム", "drums"],
      ["キーボード", "keyboard"],
      ["バンド演奏", "band"]
    ]
  end

  def self.future_performance_type_labels
    FUTURE_PERFORMANCE_TYPE_LABELS.except("guitar", "bass", "drums", "keyboard", "band").values
  end

  def priority_analysis?
    customer&.has_feature?(:singing_diagnosis_priority)
  end

  def performance_type_label
    PERFORMANCE_TYPE_LABELS.fetch(performance_type, "ボーカル")
  end

  def reference_input
    payload = result_payload
    return {} unless payload.respond_to?(:[])

    payload[:reference_input] || payload["reference_input"] || {}
  end

  def reference_comparison
    payload = result_payload
    return {} unless payload.respond_to?(:[])

    payload[:reference_comparison] || payload["reference_comparison"] || {}
  end

  def previous_completed_diagnosis
    return nil if customer.blank? || created_at.blank?
    return nil unless completed?

    customer.singing_diagnoses
      .completed
      .where(performance_type: performance_type)
      .where("created_at < ? OR (created_at = ? AND id < ?)", created_at, created_at, id)
      .order(created_at: :desc, id: :desc)
      .first
  end

  def score_comparison(previous_diagnosis = previous_completed_diagnosis)
    return nil if previous_diagnosis.blank?

    SCORE_ATTRIBUTES.index_with do |attribute|
      current_value = public_send(attribute)
      previous_value = previous_diagnosis.public_send(attribute)

      {
        current: current_value,
        previous: previous_value,
        delta: score_delta(current_value, previous_value)
      }
    end
  end

  def specific_score_comparison(previous_diagnosis = previous_completed_diagnosis)
    return nil if previous_diagnosis.blank?
    return nil unless completed? && previous_diagnosis.completed?
    return nil unless performance_type == previous_diagnosis.performance_type

    current_scores = specific_scores_from_payload(result_payload)
    previous_scores = specific_scores_from_payload(previous_diagnosis.result_payload)
    shared_keys = current_scores.keys & previous_scores.keys
    return {} if shared_keys.blank?

    shared_keys.each_with_object({}) do |key, comparison|
      current_value = current_scores[key]
      previous_value = previous_scores[key]

      comparison[key] = {
        current: current_value,
        previous: previous_value,
        delta: score_delta(current_value, previous_value)
      }
    end
  end

  private

  def audio_file_attached
    errors.add(:audio_file, "を添付してください") unless audio_file.attached?
  end

  def specific_scores_from_payload(payload)
    return {} unless payload.respond_to?(:[])

    specific = payload[:specific] || payload["specific"]
    return {} unless specific.respond_to?(:each_with_object)

    specific.each_with_object({}) do |(key, value), scores|
      scores[key.to_sym] = value if value.present?
    end
  end

  def score_delta(current_value, previous_value)
    return nil if current_value.nil? || previous_value.nil?

    current_value.to_i - previous_value.to_i
  end
end
