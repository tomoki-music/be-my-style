# Business のコミュニティ タイムライン(CommunityPost) / プロジェクト チャット(ProjectChat) で共通の
# 「本文 + スタンプ + 添付ファイル」を扱う。
#
# 添付の閲覧は Business::ChatAttachmentsController 経由に限定し、ActiveStorage の
# 恒久的な blob URL(url_for / rails_blob_path)は画面に出さない。
module BusinessChatContent
  extend ActiveSupport::Concern

  include Stampable

  # Business のスタンプ選択タブ。素材・表示名は Stampable::STAMP_DEFINITIONS を再利用し、
  # music の3分類(シンプル / 人物 / どうぶつ)を「動物か、それ以外か」の2タブにまとめる。
  # 人物イラストは動物ではないため「シンプル」側に入れる(SVG → 人物 の順)。
  STAMP_TABS = {
    simple: { label: "シンプル", source_categories: %i[simple human] },
    animal: { label: "動物",     source_categories: %i[animal] }
  }.freeze

  # { tab => { label:, definitions: { key => definition } } }。
  # 選択 UI と許可リスト(STAMP_TYPES)はどちらもこの一覧から作り、両者がずれないようにする。
  # 素材のないレガシー絵文字スタンプ(Stampable::LEGACY_STAMP_LABELS)は含めない。
  STAMP_TAB_DEFINITIONS = STAMP_TABS.transform_values { |tab|
    by_category = Stampable.definitions_by_category
    definitions = tab[:source_categories].map { |category| by_category.fetch(category) }.reduce({}, :merge)
    { label: tab[:label], definitions: definitions.freeze }.freeze
  }.freeze

  STAMP_TYPES = STAMP_TAB_DEFINITIONS.values.flat_map { |tab| tab[:definitions].keys }.freeze

  MAX_ATTACHMENTS = 5
  MAX_ATTACHMENT_SIZE = 10.megabytes

  # 拡張子ごとに、中身(ActiveStorage が Marcel で判定した content_type)として許可する形式。
  # 拡張子と中身の両方が一致したものだけを受け付けるため、名前だけ偽装した実行ファイル等は弾かれる。
  # SVG / HTML は表示時にスクリプトが動く恐れがあるため許可しない。
  ALLOWED_ATTACHMENT_TYPES = {
    "jpg"  => %w[image/jpeg],
    "jpeg" => %w[image/jpeg],
    "png"  => %w[image/png],
    "gif"  => %w[image/gif],
    "webp" => %w[image/webp],
    "pdf"  => %w[application/pdf],
    # 旧 Office 形式は Marcel が OLE コンテナとしか判定できない場合がある。
    "doc"  => %w[application/msword application/x-ole-storage],
    "xls"  => %w[application/vnd.ms-excel application/x-ole-storage],
    "ppt"  => %w[application/vnd.ms-powerpoint application/x-ole-storage],
    "docx" => %w[application/vnd.openxmlformats-officedocument.wordprocessingml.document],
    "xlsx" => %w[application/vnd.openxmlformats-officedocument.spreadsheetml.sheet],
    "pptx" => %w[application/vnd.openxmlformats-officedocument.presentationml.presentation]
  }.freeze

  INLINE_IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  # 画面の案内・ファイル選択の accept 属性に使う。
  def self.accept_attribute
    ALLOWED_ATTACHMENT_TYPES.keys.map { |ext| ".#{ext}" }.join(",")
  end

  def self.limits_description
    "画像(JPG・PNG・GIF・WebP)、PDF、Word・Excel・PowerPoint／1ファイル#{MAX_ATTACHMENT_SIZE / 1.megabyte}MBまで・最大#{MAX_ATTACHMENTS}件"
  end

  # タブ順(先頭が初期表示)を保ったタブ別のスタンプ定義。
  def self.stamp_tabs
    STAMP_TAB_DEFINITIONS
  end

  # 「シンプル」タブには同じ表示名の SVG と人物イラストが並ぶため、読み上げ・確認文では人物を区別する。
  def self.stamp_accessible_name(definition)
    definition[:category] == :human ? "#{definition[:label]}（人物）" : definition[:label]
  end

  def self.inline_image?(attachment)
    INLINE_IMAGE_TYPES.include?(attachment.content_type)
  end

  included do
    has_many_attached :attachments

    # legacy: この機能以前の投稿。投稿当時と同じ表示方式で描画する。
    # markdown: 書式ボタンがあった時期の投稿。Chat::MarkdownRenderer で描画する。
    # plain: 現在の入力欄(書式なし)の投稿。本文はすべて文字として表示し、改行と URL のリンクだけを付ける。
    # 過去の投稿は保存し直さず、それぞれの形式のまま表示する。
    enum content_format: { legacy: 0, markdown: 1, plain: 2 }, _prefix: :content_format

    # 送信済みのスタンプは変更されない限り再検証しない(許可リストを見直しても既存投稿は表示・保存できる)。
    validate :stamp_type_allowed_for_business, if: :will_save_change_to_stamp_type?
    validate :body_or_stamp_or_attachment_present
    validate :attachments_acceptable
  end

  private

  # Stampable 側の検証(全スタンプ)に加え、Business で用意したスタンプだけに絞る。
  def stamp_type_allowed_for_business
    return if stamp_type.blank? || STAMP_TYPES.include?(stamp_type)

    errors.add(:base, "選択されたスタンプは利用できません")
  end

  def body_or_stamp_or_attachment_present
    return if body.present? || stamped? || attachments.attached?

    errors.add(:base, "メッセージを入力するか、スタンプ・ファイルを選んでください")
  end

  def attachments_acceptable
    return unless attachments.attached?

    if attachments.size > MAX_ATTACHMENTS
      errors.add(:base, "添付ファイルは#{MAX_ATTACHMENTS}件までです")
    end

    attachments.each do |attachment|
      blob = attachment.blob
      name = blob.filename.to_s
      extension = blob.filename.extension_without_delimiter.to_s.downcase

      unless ALLOWED_ATTACHMENT_TYPES.fetch(extension, []).include?(blob.content_type)
        errors.add(:base, "「#{name}」は添付できない形式です")
        next
      end

      if blob.byte_size > MAX_ATTACHMENT_SIZE
        errors.add(:base, "「#{name}」は#{MAX_ATTACHMENT_SIZE / 1.megabyte}MBを超えています")
      end
    end
  end
end
