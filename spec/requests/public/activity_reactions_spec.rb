require 'rails_helper'

RSpec.describe "Public::ActivityReactions", type: :request do
  let!(:customer) { create(:customer) }
  let!(:activity) { create(:activity) }

  describe "POST /public/activities/:activity_id/reactions" do
    context "ログイン済みの場合" do
      before { sign_in customer }

      it "リアクションを新規作成し200を返すこと" do
        post public_activity_reactions_path(activity, reaction_type: "fire"),
          headers: { "Accept" => "application/json" }

        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json["reacted"]).to eq true
        expect(json["count"]).to eq 1
        expect(ActivityReaction.count).to eq 1
      end

      it "同じリアクションを再度POSTするとトグルで削除され count が 0 になること" do
        create(:activity_reaction, customer: customer, activity: activity, reaction_type: "fire")

        post public_activity_reactions_path(activity, reaction_type: "fire"),
          headers: { "Accept" => "application/json" }

        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json["reacted"]).to eq false
        expect(json["count"]).to eq 0
        expect(ActivityReaction.count).to eq 0
      end

      it "異なるreaction_typeは独立して保存されること" do
        post public_activity_reactions_path(activity, reaction_type: "fire"),
          headers: { "Accept" => "application/json" }
        post public_activity_reactions_path(activity, reaction_type: "clap"),
          headers: { "Accept" => "application/json" }

        expect(ActivityReaction.count).to eq 2
      end

      it "無効なreaction_typeは422を返すこと" do
        post public_activity_reactions_path(activity, reaction_type: "invalid"),
          headers: { "Accept" => "application/json" }

        expect(response.status).to eq 422
      end

      it "他人の投稿にもリアクションできること" do
        other_activity = create(:activity)
        post public_activity_reactions_path(other_activity, reaction_type: "fire"),
          headers: { "Accept" => "application/json" }

        expect(response.status).to eq 200
        expect(ActivityReaction.count).to eq 1
      end

      it "存在しないactivity_idでは404を返すこと" do
        post "/public/activities/999999/reactions",
          params: { reaction_type: "fire" },
          headers: { "Accept" => "application/json" }

        expect(response.status).to eq 404
      end
    end

    context "未ログインの場合" do
      it "認証エラーになること" do
        post public_activity_reactions_path(activity, reaction_type: "fire"),
          headers: { "Accept" => "application/json" }

        expect(response.status).not_to eq 200
      end
    end
  end
end
