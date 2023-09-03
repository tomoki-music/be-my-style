require 'rails_helper'

RSpec.describe "Public::Favorites", type: :request do
  let(:customer) { create(:customer, :customer_with_parts) }
  let(:customer2) { create(:customer, :customer_with_parts) }
  let(:activity) { create(:activity, customer: customer) }

  describe "いいねアクションのテスト" do
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
end
