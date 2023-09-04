require 'rails_helper'

RSpec.describe Activity, type: :model do
  let(:customer) { create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:activity) { create(:activity, customer: customer) }
  let!(:favorite) { FactoryBot.create(:favorite, customer_id: other_customer.id, activity_id: activity.id) }

  describe 'アソシエーションのテスト' do
    context 'customerモデルとの関係' do
      it 'customerとN:1となっている' do
        expect(Activity.reflect_on_association(:customer).macro).to eq :belongs_to
      end
    end
    context 'Favoriteモデルとの関係' do
      it 'favoriteと1:Nとなっている' do
        expect(Activity.reflect_on_association(:favorites).macro).to eq :has_many
      end
    end
  end
  describe 'バリデーションのテスト' do
    context '10MB以上のファイルをupload' do
      it "バリデーションエラー" do
        activity.activity_video = Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec/fixtures/11megabytes_sample.png'))
        is_expected.to be_invalid
      end
    end
    context '必須項目が空欄の場合エラー' do
      it "titleが空欄の場合" do
        activity.title = ""
        is_expected.to be_invalid
      end
      it "keepが空欄の場合" do
        activity.keep = ""
        is_expected.to be_invalid
      end
      it "problemが空欄の場合" do
        activity.problem = ""
        is_expected.to be_invalid
      end
      it "tryが空欄の場合" do
        activity.try = ""
        is_expected.to be_invalid
      end
    end
  end
  describe 'モデルのインスタンスメソッドのテスト' do
    context 'いいねしているか？メソッドテスト' do
      it 'いいねしているかチェックする' do
        expect(activity.favorited?(other_customer)).to eq true
      end
    end
  end
end
