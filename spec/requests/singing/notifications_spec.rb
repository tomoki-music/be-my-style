require "rails_helper"

RSpec.describe "Singing::Notifications", type: :request do
  let(:visited) { create(:customer, domain_name: "singing", name: "通知を受ける人") }
  let(:visitor) { create(:customer, domain_name: "singing", name: "応援する人") }

  describe "GET /singing/notifications" do
    it "singingユーザーが通知一覧でプロフィール応援リアクション通知を見られること" do
      sign_in visited
      visitor.active_notifications.create!(
        visited: visited,
        action: "singing_profile_reaction_cheer"
      )

      get singing_notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("通知一覧")
      expect(response.body).to include("応援する人さん")
      expect(response.body).to include("あなたのプロフィール")
      expect(response.body).to include("『応援してます！』を送りました")
    end

    it "表示した通知を既読にすること" do
      sign_in visited
      notification = visitor.active_notifications.create!(
        visited: visited,
        action: "singing_profile_reaction_growth",
        checked: false
      )

      get singing_notifications_path

      expect(response).to have_http_status(:ok)
      expect(notification.reload.checked).to eq true
    end

    it "通知がない場合も一覧を表示できること" do
      sign_in visited

      get singing_notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("通知はありません")
    end

    it "未ログインではログイン画面へリダイレクトすること" do
      get singing_notifications_path

      expect(response).to redirect_to(new_customer_session_path)
    end
  end
end
