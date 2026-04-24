class AddSingingDomain < ActiveRecord::Migration[6.1]
  def up
    Domain.find_or_create_by!(name: "singing")
  end

  def down
    Domain.find_by(name: "singing")&.destroy
  end
end
