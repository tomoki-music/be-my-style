class Project < ApplicationRecord
  belongs_to :community
  belongs_to :customer
end
