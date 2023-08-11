require 'rails_helper'

RSpec.describe "Public::Activities", type: :request do
  let(:customer) { create(:customer) }
  let(:activity) { create(:activity, customer_id: customer.id) }

  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "activity一覧ページ(index)が正しく表示される" do
      before do
        get public_activities_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "activity詳細ページ(show)が正しく表示される" do
      before do
        get public_activity_path(activity)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "activity新規作成ページ(new)が正しく表示される" do
      before do
        get new_public_activity_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "activity新規作成(create)が正しく処理され登録される" do
      it "activityの作成が成功する" do
        expect do
          post public_activities_path, params: {
            activity: {
              title: "MMM最高！",
              introduction: "楽しいコミュニティです！",
            }
          }
        end.to change(Activity, :count).by(1)
      end
    end
  end

  describe '非ログイン' do
    context "activities一覧ページ(index)へ遷移されない" do
      before do
        get public_activities_path
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "activity詳細ページ(show)へ遷移されない" do
      before do
        get public_activity_path(activity)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "activity新規作成ページ(new)へ遷移されない" do
      before do
        get new_public_activity_path
      end
      it 'リクエストは302 OKとなること' do
        expect(response.status).to eq 302
      end
    end
    context "activity新規作成(create)が正しく処理されない" do
      it "activityの作成に失敗する" do
        post public_activities_path, params: {
          activity: {
            title: "MMM最高！",
            introduction: "楽しいコミュニティです！",
          }
        }
        expect(response.status).to eq 302
      end
    end
  end
end
