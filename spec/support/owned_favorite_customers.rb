# Activities::AdminFavoriteAdder の対象(会員 ID 2〜10)を ID 固定で作る。
# 先に固定 ID の会員を作ってから他の会員を作らないと、自動採番と ID がぶつかるため、各 spec の最初に呼ぶ。
module OwnedFavoriteCustomers
  def create_owned_favorite_customers(ids = Activities::AdminFavoriteAdder::OWNED_CUSTOMER_IDS)
    ids.map { |id| create(:customer, id: id) }
  end
end

RSpec.configure do |config|
  config.include OwnedFavoriteCustomers
end
