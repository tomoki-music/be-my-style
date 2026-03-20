class ProjectMember < ApplicationRecord
  belongs_to :project
  belongs_to :customer
end
