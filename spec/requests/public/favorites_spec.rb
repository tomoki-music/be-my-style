require 'rails_helper'

RSpec.describe "Public::Favorites", type: :request do
  let(:customer) { create(:customer, :customer_with_parts) }
  let(:customer2) { create(:customer, :customer_with_parts) }
  let(:activity) { create(:activity, customer: customer) }

  describe "ログイン時のテスト" do
    context "いいねが正しく行われる" do
      before do
        sign_in customer2
        get public_activity_path(activity)
      end
      it "いいねが成功する" do
        expect do
          post public_activity_favorites_path(activity), params: {
            favorite: {
              customer_id: customer2.id,
              activity_id: activity.id,
            }
          }
        end.to change(Favorite, :count).by(1)
      end
    end
    context "いいねの取り消しが正しく行われる" do
      before do
        sign_in customer2
        get public_activity_path(activity)
        post public_activity_favorites_path(activity), params: {
          favorite: {
            customer_id: customer2.id,
            activity_id: activity.id,
          }
        }
      end
      it "いいねの取り消しが成功する" do
        expect do
          delete public_activity_favorites_path(activity), params: {
            favorite: {
              customer_id: customer2.id,
              activity_id: activity.id,
            }
          }
        end.to change(Favorite, :count).by(-1)
      end
    end
  end

  describe '非ログイン' do
    context "いいねが正しく行われる" do
      before do
        get public_activity_path(activity)
      end
      it "いいねが失敗する" do
        expect do
          post public_activity_favorites_path(activity), params: {
            favorite: {
              customer_id: customer2.id,
              activity_id: activity.id,
            }
          }
        end.to eq 302
      end
    end
    context "いいねの取り消しが失敗する（302FOUND）" do
      before do
        sign_in customer2
        get public_activity_path(activity)
        post public_activity_favorites_path(activity), params: {
          favorite: {
            customer_id: customer2.id,
            activity_id: activity.id,
          }
        }
        sign_out customer2
      end
      it "いいねの取り消しが失敗する（302FOUND）" do
        expect do
          delete public_activity_favorites_path(activity), params: {
            favorite: {
              customer_id: customer2.id,
              activity_id: activity.id,
            }
          }
        end.to eq 302
      end
    end
  end

end

# 画面と同じ Ajax(remote: true)での「いいね」。Favorite.add_unique で記事をロックしてから登録する。
RSpec.describe "Public::Favorites(Ajax)", type: :request do
  let(:author) { create(:customer, :customer_with_parts) }
  let(:fan) { create(:customer, :customer_with_parts) }
  let(:activity) { create(:activity, customer: author) }

  before { sign_in fan }

  it "続けて送っても1件だけ登録し、通知も1件だけ作る" do
    expect do
      2.times { post public_activity_favorites_path(activity), xhr: true }
    end.to change { Favorite.where(activity: activity, customer: fan).count }.by(1)
      .and change { Notification.where(action: "favorite", activity_id: activity.id).count }.by(1)

    expect(response).to have_http_status(:ok)
  end
end
