class LearningStudent < ApplicationRecord
  belongs_to :customer
  belongs_to :learning_school_group, optional: true
  has_many :learning_student_parts, dependent: :destroy
  has_many :learning_student_trainings, dependent: :destroy
  has_many :learning_progress_logs, dependent: :destroy
  has_many :learning_band_memberships, dependent: :destroy
  has_many :learning_bands, through: :learning_band_memberships
  has_many :learning_effort_points, dependent: :destroy
  has_many :learning_portal_accesses, dependent: :destroy

  validates :name, presence: true, length: { maximum: 50 }
  validates :nickname, length: { maximum: 30 }, allow_blank: true
  validates :main_part, presence: true, inclusion: { in: LearningCatalog::PARTS.keys }
  validates :status, presence: true, inclusion: { in: LearningCatalog::STUDENT_STATUSES.keys }
  validates :grade, length: { maximum: 50 }
  validates :email, length: { maximum: 255 }, allow_blank: true,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "はメールアドレス形式で入力してください" }

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(status: "active") }
  scope :with_filters, lambda { |params|
    scope = all
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(main_part: params[:part]) if params[:part].present?
    scope = scope.where(learning_school_group_id: params[:learning_school_group_id]) if params[:learning_school_group_id].present?
    if params[:keyword].present?
      keyword = "%#{sanitize_sql_like(params[:keyword])}%"
      scope = scope.where("learning_students.name LIKE ? OR learning_students.memo LIKE ?", keyword, keyword)
    end
    scope
  }

  before_validation :ensure_public_access_token

  def display_name
    nickname.present? ? nickname : name
  end

  def achievement_rate
    total = learning_student_trainings.count
    return 0.0 if total.zero?

    achieved = learning_student_trainings.where(status: "achieved").count
    (achieved.to_f / total * 100).round(1)
  end

  def rank_within_group
    return nil unless learning_school_group

    siblings = learning_school_group.learning_students.active
                                    .order(total_effort_points: :desc)
                                    .pluck(:id)
    pos = siblings.index(id)
    pos ? pos + 1 : nil
  end

  def displayed_parts
    codes = learning_student_parts.order(primary: :desc, part: :asc).pluck(:part)
    codes = [main_part] if codes.blank?
    codes.uniq
  end

  def related_band_trainings
    LearningBandTraining
      .joins(:learning_band)
      .where(learning_band: { id: learning_band_ids })
      .ordered
      .select { |training| (training.related_parts_list & displayed_parts).present? || training.related_parts_list.blank? }
  end

  def portal_url
    Rails.application.routes.url_helpers.learning_student_portal_url(public_access_token)
  end

  def sync_parts!(parts)
    normalized_parts = Array(parts).map(&:presence).compact.uniq
    normalized_parts.unshift(main_part) unless normalized_parts.include?(main_part)

    transaction do
      learning_student_parts.where.not(part: normalized_parts).destroy_all

      normalized_parts.each do |part|
        record = learning_student_parts.find_or_initialize_by(part: part)
        record.primary = (part == main_part)
        record.save!
      end
    end
  end

  private

  def ensure_public_access_token
    self.public_access_token ||= loop do
      token = SecureRandom.urlsafe_base64(24)
      break token unless self.class.exists?(public_access_token: token)
    end
  end
end
