class CaptionVideo < ApplicationRecord
  MAX_SOURCE_VIDEO_BYTES = 500.megabytes
  MAX_DURATION_SECONDS = 1800 # 30分。CaptionVideos::AudioExtractorの音声ビットレート(64kbps)を
  # 前提とすると、この上限でも抽出音声は最大約14MBでMAX_AUDIO_BYTES(24MB)に収まるため、
  # 音声分割は不要(spec/services/caption_videos/audio_extractor_spec.rb で担保)。
  ALLOWED_SOURCE_CONTENT_TYPES = %w[video/mp4 video/quicktime].freeze
  # ブラウザ/OSによってはMOVに対し空文字やapplication/octet-streamしか申告しないことがあるため、
  # 拡張子が正しければ許容する(実体はffprobeで別途検証するため、ここで緩めても安全性は落ちない)。
  GENERIC_SOURCE_CONTENT_TYPES = %w[application/octet-stream].freeze
  ALLOWED_SOURCE_EXTENSIONS = %w[.mp4 .mov].freeze
  TITLE_MAX_LENGTH = 100
  ERROR_MESSAGE_MAX_LENGTH = 500

  belongs_to :customer

  # SingingGeneratedRecapMovie(歌声診断Recap Movie)に倣い、レコード削除時にストレージ上の
  # ファイルが確実に(DBトランザクションのコミット後に)破棄されるよう purge_later を使う。
  has_one_attached :source_video, dependent: :purge_later
  # 文字起こし用に抽出した音声。転写完了後は不要になるため purge_later で破棄する。
  has_one_attached :extracted_audio, dependent: :purge_later
  # テロップ焼き込み済みの完成動画。再生成時は attach し直すことで自動的に旧ファイルへ置き換わる。
  has_one_attached :rendered_video, dependent: :purge_later

  has_many :video_captions, -> { order(:display_order, :id) }, dependent: :destroy, inverse_of: :caption_video
  accepts_nested_attributes_for :video_captions, allow_destroy: true

  enum status: {
    uploaded:         "uploaded",
    extracting_audio: "extracting_audio",
    transcribing:      "transcribing",
    ready_for_edit:    "ready_for_edit",
    rendering:         "rendering",
    completed:         "completed",
    failed:            "failed"
  }

  validates :status, presence: true
  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validates :selected_template, presence: true
  validates :transcript_language, presence: true
  validate :source_video_attached
  validate :source_video_content_type
  validate :source_video_extension
  validate :source_video_size

  EDITABLE_STATUSES = %w[ready_for_edit rendering completed failed].freeze

  def failed?
    status == "failed"
  end

  def processing?
    %w[extracting_audio transcribing rendering].include?(status)
  end

  def render_requestable?
    %w[ready_for_edit completed failed].include?(status) && video_captions.exists?
  end

  def editable?
    EDITABLE_STATUSES.include?(status)
  end

  def landscape?
    width.present? && height.present? && width >= height
  end

  # ジョブが一時ファイルを書き出す際の拡張子。ffmpeg/ffprobeは拡張子でなく実バイトを見て
  # コンテナ形式を判定するため処理結果には影響しないが、一時ファイルの内容が
  # デバッグ時に分かりやすいよう、検証済みのアップロード時拡張子をそのまま使う。
  def source_video_local_extension
    return ".mp4" unless source_video.attached?

    ext = File.extname(source_video.filename.to_s).downcase
    ALLOWED_SOURCE_EXTENSIONS.include?(ext) ? ext : ".mp4"
  end

  def mark_processing!(new_status)
    update!(status: new_status, error_message: nil, processing_started_at: Time.current, processing_completed_at: nil)
  end

  def mark_completed!
    update!(status: "completed", processing_completed_at: Time.current, error_message: nil)
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message.to_s.truncate(ERROR_MESSAGE_MAX_LENGTH), processing_completed_at: Time.current)
  end

  # ユーザー向けの処理状況メッセージ。技術的な例外内容は含めない。
  def status_message
    case status
    when "uploaded"          then "アップロード完了。音声を準備しています。"
    when "extracting_audio"  then "音声を準備しています。"
    when "transcribing"      then "AIが文字起こししています。"
    when "ready_for_edit"    then "テロップを確認できます。"
    when "rendering"         then "動画を生成しています。"
    when "completed"         then "完成しました。"
    when "failed"            then "処理に失敗しました。"
    end
  end

  private

  def source_video_attached
    errors.add(:source_video, "を選択してください") unless source_video.attached?
  end

  def source_video_content_type
    return unless source_video.attached?

    content_type = source_video.content_type.to_s
    return if content_type.blank? # ブラウザ/OSがMOVにContent-Typeを付与しないケースを許容する
    return if ALLOWED_SOURCE_CONTENT_TYPES.include?(content_type)
    return if GENERIC_SOURCE_CONTENT_TYPES.include?(content_type)

    errors.add(:source_video, "はMP4またはMOV形式のみアップロードできます")
  end

  def source_video_extension
    return unless source_video.attached?

    ext = File.extname(source_video.filename.to_s).downcase
    unless ALLOWED_SOURCE_EXTENSIONS.include?(ext)
      errors.add(:source_video, "はMP4(.mp4)またはMOV(.mov)ファイルのみアップロードできます")
    end
  end

  def source_video_size
    return unless source_video.attached?

    if source_video.byte_size > MAX_SOURCE_VIDEO_BYTES
      errors.add(:source_video, "は500MB以内にしてください")
    end
  end
end
