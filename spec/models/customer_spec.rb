require 'rails_helper'

RSpec.describe 'Customerモデルのテスト', type: :model do
  describe 'バリデーションのテスト' do
    let(:customer) { FactoryBot.create(:customer) }
    let(:other_customer) { FactoryBot.create(:customer) }

    context 'nameカラムが不正' do
      it '空欄でないこと' do
        customer.name = ''
        expect(customer.valid?).to eq false
      end
      it '20文字以下であること' do
        customer.name = Faker::Lorem.characters(number:21)
        expect(customer.valid?).to eq false
      end
    end
    context 'emailカラムが不正' do
      it '空欄でないこと' do
        customer.email = ''
        expect(customer.valid?).to eq false
      end
      it '一意性のあるメールアドレスである事' do
        customer.email = other_customer.email
        expect(customer.valid?).to eq false
      end
    end
  end
  # describe 'アソシエーションのテスト' do
  #   context 'customerモデルとの関係' do
  #     it 'N:1となっている' do
  #       expect(Post.reflect_on_association(:user).macro).to eq :belongs_to
  #     end
  #   end

  #   # has_manyの関係性で記述するのもありです。
  #   # context 'PostCommentモデルとの関係' do
  #     # it '1:Nとなっている' do
  #       # expect(Post.reflect_on_association(:post_comments).macro).to eq :has_many
  #     # end
  #   # end
  # end
end
