class LearningSchoolGroup < ApplicationRecord
  belongs_to :customer
  has_many :learning_students, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :customer_id }
  validates :memo, length: { maximum: 1000 }

  scope :ordered, -> { order(:name) }
  scope :with_filters, lambda { |params|
    scope = all
    if params[:keyword].present?
      keyword = "%#{sanitize_sql_like(params[:keyword])}%"
      scope = scope.where("learning_school_groups.name LIKE ? OR learning_school_groups.memo LIKE ?", keyword, keyword)
    end
    scope
  }
end
