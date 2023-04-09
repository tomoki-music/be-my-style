require 'rails_helper'

RSpec.describe 'Customerモデルのテスト', type: :model do
  describe 'バリデーションのテスト' do
    let(:customer) { FactoryBot.create(:customer) }

    context 'nameカラム' do
      it '空欄でないこと' do
        customer.name = ''
        expect(customer.valid?).to eq false
      end
      it '20文字以下であること' do
        customer.name = Faker::Lorem.characters(number:21)
        expect(customer.valid?).to eq false;
      end
    end
  end
end
