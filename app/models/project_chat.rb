class ProjectChat < ApplicationRecord
  include BusinessChatContent

  belongs_to :project
  belongs_to :customer
end
