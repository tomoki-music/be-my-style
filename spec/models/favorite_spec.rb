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

RSpec.describe Favorite, ".add_unique", type: :model do
  let(:author) { create(:customer) }
  let(:fan) { create(:customer) }
  let(:activity) { create(:activity, customer: author) }

  it "未登録なら登録し、登録済みなら重複させずに nil を返す" do
    expect(Favorite.add_unique(activity: activity, customer: fan)).to be_a(Favorite)
    expect(Favorite.add_unique(activity: activity, customer: fan)).to be_nil
    expect(Favorite.where(activity: activity, customer: fan).count).to eq(1)
  end

  it "同じ会員・記事の組み合わせは検証でも重複を拒否する" do
    Favorite.create!(activity: activity, customer: fan)
    expect(Favorite.new(activity: activity, customer: fan)).not_to be_valid
  end
end
