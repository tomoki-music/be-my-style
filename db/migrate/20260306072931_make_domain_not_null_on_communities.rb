class MakeDomainNotNullOnCommunities < ActiveRecord::Migration[6.1]
  def change
    change_column_null :communities, :domain_id, false
  end
end
