require 'rails_helper'

RSpec.describe Activity, type: :model do
  let(:customer) { create(:customer) }
  let(:activity) { create(:activity, customer: customer) }

  describe 'アソシエーションのテスト' do
    context 'customerモデルとの関係' do
      it 'customerとN:1となっている' do
        expect(Activity.reflect_on_association(:customer).macro).to eq :belongs_to
      end
    end
  end
  describe 'モデルメソッドのテスト' do
    context '10MB以上のファイルをupload' do
      it "バリデーションエラー" do
        activity.activity_video = Rack::Test::UploadedFile.new(File.join(Rails.root, 'spec/fixtures/11megabytes_sample.png'))
        is_expected.to be_invalid
      end
    end
  end
end
