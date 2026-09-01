class CustomerFeedback < ApplicationRecord
  # 件名・本文の文字数上限。長文でも主要画面が崩れないための上限。
  SUBJECT_MAX_LENGTH = 100
  BODY_MAX_LENGTH = 2000
  ADMIN_NOTE_MAX_LENGTH = 5000

  belongs_to :customer

  # 日本語は DB に保存せず、英語識別値(整数 enum)で保持し表示時に I18n 変換する。
  # 既存 enum(Post など)と同じ整数バッキング。将来キーを増やす場合は末尾に追加し、
  # 既存の数値は変更しない(並び替え・再利用しない)。
  enum category: {
    feature_request: 0,
    bug_report: 1,
    consultation: 2,
    other: 3
  }

  enum status: {
    unread: 0,
    reviewing: 1,
    completed: 2
  }

  validates :category, presence: true
  validates :status, presence: true
  validates :subject, length: { maximum: SUBJECT_MAX_LENGTH }
  validates :body, presence: true, length: { maximum: BODY_MAX_LENGTH }
  validates :admin_note, length: { maximum: ADMIN_NOTE_MAX_LENGTH }, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }

  # フォームのカテゴリー選択肢([表示名, 値])。
  def self.category_options
    categories.keys.map { |key| [category_label(key), key] }
  end

  def self.category_label(key)
    I18n.t("enums.customer_feedback.category.#{key}")
  end

  def self.status_label(key)
    I18n.t("enums.customer_feedback.status.#{key}")
  end

  def category_label
    self.class.category_label(category)
  end

  def status_label
    self.class.status_label(status)
  end
end
