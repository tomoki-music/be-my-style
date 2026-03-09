class AssignMusicDomainToExistingCustomers < ActiveRecord::Migration[6.1]
  def up
    music = Domain.find_by(name: "music")

    Customer.find_each do |customer|
      CustomerDomain.create!(
        customer_id: customer.id,
        domain_id: music.id
      )
    end
  end

  def down
    CustomerDomain.delete_all
  end
end
