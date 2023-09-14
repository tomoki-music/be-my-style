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
