class AddDomainToCommunities < ActiveRecord::Migration[6.1]
  def up
    add_reference :communities, :domain, foreign_key: true
  end

  def down
    remove_reference :communities, :domain, foreign_key: true
  end
end
