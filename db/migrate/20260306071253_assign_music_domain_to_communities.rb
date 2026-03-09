class AssignMusicDomainToCommunities < ActiveRecord::Migration[6.1]
  class Domain < ApplicationRecord; end
  class Community < ApplicationRecord; end

  def up
    music = Domain.find_or_create_by!(name: "music")
    Community.update_all(domain_id: music.id)
  end
end