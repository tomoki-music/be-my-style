require 'rails_helper'

RSpec.describe SongCustomer, type: :model do
  context 'Customerモデルとの関係' do
    it 'customerとN:1となっている' do
      expect(SongCustomer.reflect_on_association(:customer).macro).to eq :belongs_to
    end
  end
  context 'Songモデルとの関係' do
    it 'songとN:1となっている' do
      expect(SongCustomer.reflect_on_association(:song).macro).to eq :belongs_to
    end
  end
end
