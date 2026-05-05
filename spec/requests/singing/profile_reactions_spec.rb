require "rails_helper"

RSpec.describe "Singing::ProfileReactions", type: :request do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:target_customer) { create(:customer, domain_name: "singing") }

  describe "POST /singing/users/:user_id/profile_reaction" do
    before { sign_in customer }

    it "プロフィールに応援リアクションを追加できること" do
      post singing_user_profile_reaction_path(target_customer, reaction_type: "cheer"),
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["reacted"]).to eq true
      expect(json["count"]).to eq 1
      expect(SingingProfileReaction.count).to eq 1
    end

    it "プロフィールに応援リアクションすると対象ユーザーに通知を作成すること" do
      expect do
        post singing_user_profile_reaction_path(target_customer, reaction_type: "cheer"),
          headers: { "Accept" => "application/json" }
      end.to change(Notification, :count).by(1)

      notification = Notification.last
      expect(notification.visitor).to eq customer
      expect(notification.visited).to eq target_customer
      expect(notification.action).to eq "singing_profile_reaction_cheer"
    end

    it "同じプロフィールリアクションの通知を重複作成しないこと" do
      post singing_user_profile_reaction_path(target_customer, reaction_type: "cheer"),
        headers: { "Accept" => "application/json" }
      post singing_user_profile_reaction_path(target_customer, reaction_type: "cheer"),
        headers: { "Accept" => "application/json" }

      expect do
        post singing_user_profile_reaction_path(target_customer, reaction_type: "cheer"),
          headers: { "Accept" => "application/json" }
      end.not_to change(Notification, :count)

      expect(Notification.where(visitor: customer, visited: target_customer, action: "singing_profile_reaction_cheer").count).to eq 1
    end

    it "同じリアクションを再度POSTすると取り消せること" do
      create(:singing_profile_reaction, customer: customer, target_customer: target_customer, reaction_type: "cheer")

      post singing_user_profile_reaction_path(target_customer, reaction_type: "cheer"),
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["reacted"]).to eq false
      expect(json["count"]).to eq 0
      expect(SingingProfileReaction.count).to eq 0
    end

    it "別種別のリアクションは独立して追加できること" do
      post singing_user_profile_reaction_path(target_customer, reaction_type: "cheer"),
        headers: { "Accept" => "application/json" }
      post singing_user_profile_reaction_path(target_customer, reaction_type: "growth"),
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(SingingProfileReaction.count).to eq 2
    end

    it "自分のプロフィールにはリアクションできないこと" do
      post singing_user_profile_reaction_path(customer, reaction_type: "cheer"),
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:forbidden)
      expect(SingingProfileReaction.count).to eq 0
      expect(Notification.count).to eq 0
    end

    it "無効なリアクション種別は422を返すこと" do
      post singing_user_profile_reaction_path(target_customer, reaction_type: "negative"),
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "存在しないプロフィールは404を返すこと" do
      post "/singing/users/999999/profile_reaction",
        params: { reaction_type: "cheer" },
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
