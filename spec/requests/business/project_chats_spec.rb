require "rails_helper"

RSpec.describe "Business::ProjectChats", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "新規事業", description: "説明") }
  let(:free_member) { create(:customer, domain_name: "business") }

  before do
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: free_member, community: community)
  end

  def chat(body)
    post business_project_project_chats_path(project), params: { project_chat: { body: body } }
  end

  context "Free プランのプロジェクト参加者(お試し OFF)" do
    before do
      project.members << free_member
      sign_in free_member
    end

    it "チャットを閲覧・投稿できる" do
      ProjectChat.create!(project: project, customer: owner, body: "キックオフしましょう")

      get business_project_path(project)
      expect(response.body).to include("キックオフしましょう")
      expect(response.body).to include("メッセージを入力...")

      expect { chat("よろしくお願いします") }.to change(ProjectChat, :count).by(1)
      expect(response).to redirect_to(business_project_path(project))
    end
  end

  context "プロジェクト非参加者" do
    before { sign_in free_member }

    it "チャットを閲覧できない" do
      ProjectChat.create!(project: project, customer: owner, body: "内部の相談")

      get business_project_path(project)

      expect(response.body).not_to include("内部の相談")
      expect(response.body).to include("このチャットはプロジェクト参加者のみ閲覧できます")
    end

    it "チャットへ投稿できない" do
      expect { chat("割り込み") }.not_to change(ProjectChat, :count)
      expect(flash[:alert]).to eq "チャットはプロジェクト参加者のみ投稿できます。"
    end
  end
end
