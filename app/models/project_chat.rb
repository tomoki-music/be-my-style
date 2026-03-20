class ProjectChat < ApplicationRecord
  belongs_to :project
  belongs_to :customer

  validates :body, presence: true
end
