require 'rails_helper'

RSpec.describe Favorite, type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:activity) { FactoryBot.create(:activity, customer: customer) }
  let(:favorite) { FactoryBot.create(:favorite, customer: other_customer) }

  describe 'アソシエーションのテスト' do
    context 'favoriteいいね機能について' do
      it 'customersと1:Nとなっている' do
        expect(Favorite.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'activitiesと1:Nとなっている' do
        expect(Favorite.reflect_on_association(:activity).macro).to eq :belongs_to
      end
    end
  end
end
