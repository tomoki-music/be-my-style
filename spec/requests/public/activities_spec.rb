require 'rails_helper'

RSpec.describe "Public::Activities", type: :request do
  let!(:customer) { create(:customer, :customer_with_parts) }
  let!(:other_customer) { create(:customer, :customer_with_parts) }
  let!(:activity) { create(:activity, customer_id: customer.id) }

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
              keep: "コミュニティの大切さを実感！",
              problem: "メンバーとのコミュニケーションをもっと工夫せねば！",
              try: "コミュニティアプリを活用して交流をスムーズに！",
            }
          }
        end.to change(Activity, :count).by(1)
      end
    end
    context "activity編集ページ(edit)が正しく表示される" do
      it 'リクエストは200 OKとなること（投稿者本人である場合）' do
        get edit_public_activity_path(activity)
        expect(response.status).to eq 200
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        sign_in other_customer
        get edit_public_activity_path(activity)
        expect(response.status).to eq 302
      end
    end
    context "activity編集(update)が正しく処理され登録される" do
      it '記事を編集できること(投稿者本人の場合)' do
        put public_activity_path(activity), params: {
          activity: {
            title: "MMM埼玉",
            introduction: "自由なコミュニティです！",
          }
        }
        expect(activity.reload.title).to eq 'MMM埼玉'
        expect(activity.reload.introduction).to eq '自由なコミュニティです！'
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        sign_in other_customer
        put public_activity_path(activity), params: {
          activity: {
            title: "MMM埼玉",
            introduction: "自由なコミュニティです！",
          }
        }
        expect(response.status).to eq 302
      end
    end
    context "activityページを正しく削除(destroy)できる" do
      it '正しく削除できる（投稿者本人である場合）' do
        expect do
          delete public_activity_path(activity)
        end.to change(Activity, :count).by(-1)
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        sign_in other_customer
        delete public_activity_path(activity)
        expect(response.status).to eq 302
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
    context "activity編集ページ(edit)が正しく表示されない" do
      it 'リクエストは302 となること' do
        get edit_public_activity_path(activity)
        expect(response.status).to eq 302
      end
    end
    context "activity編集(update)が正しく処理され登録されない" do
      it 'リクエストは302 Foundとなること' do
        put public_activity_path(activity), params: {
          activity: {
            title: "MMM埼玉",
            introduction: "自由なコミュニティです！",
          }
        }
        expect(response.status).to eq 302
      end
    end
    context "activityページを正しく削除(destroy)できない" do
      it 'リクエストは302 Foundとなること' do
        delete public_activity_path(activity)
        expect(response.status).to eq 302
      end
    end
  end
end
