require "rails_helper"

RSpec.describe "Business::Projects のお試し設定による制限解除", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:other_community) { create(:community, owner: owner, domain: business_domain) }
  let(:free_member) { create(:customer, domain_name: "business") }

  before do
    [community, other_community].each do |target|
      CommunityCustomer.find_or_create_by!(customer: owner, community: target)
      CommunityCustomer.find_or_create_by!(customer: free_member, community: target)
    end
    sign_in free_member
  end

  def create_project(target)
    post business_projects_path, params: {
      community_id: target.id,
      project: { title: "お試し企画", description: "説明", community_id: target.id }
    }
  end

  describe "コミュニティ詳細のプロジェクト案内" do
    it "お試し OFF では core プランの案内、ON では管理メニューにプロジェクト管理を表示する(通常画面に作成ボタンは出さない)" do
      get business_community_path(community)
      expect(response.body).to include("coreでプロジェクトを始める")
      expect(response.body).not_to include(%(href="#{business_community_project_management_path(community)}"))

      community.update!(plan_restrictions_waived: true)

      get business_community_path(community)
      expect(response.body).not_to include("coreでプロジェクトを始める")
      expect(response.body).to include(%(href="#{business_community_project_management_path(community)}"))
      expect(response.body).not_to include(%(href="#{new_business_project_path(community_id: community.id)}"))

      get business_community_path(other_community)
      expect(response.body).to include("coreでプロジェクトを始める")
    end
  end

  context "お試し OFF" do
    it "Free 参加者はプロジェクトを作成できない(本来の core 制限)" do
      expect { create_project(community) }.not_to change(Project, :count)
      expect(response).to redirect_to(business_community_path(community))
    end
  end

  context "お試し ON" do
    before { community.update!(plan_restrictions_waived: true) }

    it "Free 参加者でも対象コミュニティでプロジェクトを作成できる" do
      get new_business_project_path(community_id: community.id)
      expect(response).to have_http_status(:ok)

      expect { create_project(community) }.to change(Project, :count).by(1)
    end

    it "同じ Business 内の別コミュニティには波及しない" do
      expect { create_project(other_community) }.not_to change(Project, :count)
    end

    it "参加していない Free ユーザーは作成できない(参加権限は維持)" do
      sign_in create(:customer, domain_name: "business")

      expect { create_project(community) }.not_to change(Project, :count)
    end

    it "OFF に戻すと本来の制限に戻り、作成済みデータは残る" do
      create_project(community)
      created = Project.last

      community.update!(plan_restrictions_waived: false)

      expect { create_project(community) }.not_to change(Project, :count)
      expect(Project.exists?(created.id)).to eq true
    end

    it "契約プラン・課金情報は変更しない" do
      create_project(community)

      expect(free_member.reload.plan).to eq "free"
      expect(free_member.subscription).to be_nil
    end
  end
end
