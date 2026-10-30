require "rails_helper"

# Business(NAKAMA)の利用資格(Business ドメインの登録。システム管理者は例外)が無い会員は、
# コミュニティ・プロジェクトの画面を開いても、参加・申請のリクエストを直接送っても参加できず、
# 「利用開始」(/business/join)を経てから元の画面へ戻る。音楽・歌声側の資格・所属は変えない。
RSpec.describe "Business の利用資格と参加", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "資格確認コミュニティ") }
  let(:auto_community) { create(:community, owner: owner, domain: business_domain, join_approval_mode: :auto) }
  let(:project) { Project.create!(community: community, customer: owner, title: "資格確認企画", join_approval_mode: :auto) }
  let(:music_only) { create(:customer, domain_name: "music", onboarding_done: true) }

  before { CommunityCustomer.create!(community: community, customer: owner) }

  def membership_rows
    [Permit.count, CommunityCustomer.count, ProjectJoinRequest.count, ProjectMember.count]
  end

  describe "画面を開いたとき" do
    before { sign_in music_only }

    it "コミュニティ・プロジェクトの画面は、利用開始の案内へ転送し、紹介や参加ボタンを出さない" do
      [business_community_path(community), business_project_path(project)].each do |path|
        get path
        expect(response).to redirect_to(business_join_path), path
        follow_redirect!
        expect(response.body).to include("Businessドメインの利用を開始しますか？")
        expect(response.body).to include("NAKAMA（Business）の利用開始が必要です")
        expect(response.body).not_to include("資格確認コミュニティ", "資格確認企画")
      end
    end

    it "利用開始すると元の画面へ戻り、そこで初めて参加ボタンを押せる(利用開始だけでは参加しない)" do
      get business_community_path(community)

      expect { post business_join_path }.not_to change { membership_rows }
      expect(response).to redirect_to(business_community_path(community))
      expect(music_only.reload.business_user?).to be true
      expect(music_only.music_user?).to be true

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("参加を申請する")
    end

    it "プロジェクトの画面から利用開始しても、親コミュニティの参加が必要なのは変わらない" do
      get business_project_path(project)
      post business_join_path
      expect(response).to redirect_to(business_project_path(project))

      follow_redirect!
      expect(response).to redirect_to(business_community_path(community))
      expect(flash[:alert]).to include("先にコミュニティへの参加が必要です")
    end
  end

  describe "参加・申請のリクエストを直接送ったとき" do
    before { sign_in music_only }

    it "承認制・自動承認のコミュニティとも参加・申請を作らず、利用開始へ案内する" do
      [community, auto_community].each do |target|
        expect { post business_community_permit_path(target) }.not_to change { membership_rows }
        expect(response).to redirect_to(business_join_path)
        expect(flash[:alert]).to include("NAKAMA（Business）の利用開始が必要です")
      end
    end

    it "親コミュニティの参加データがあっても、プロジェクトへの参加(自動承認)・申請は作らない" do
      CommunityCustomer.create!(community: community, customer: music_only)
      manual_project = Project.create!(community: community, customer: owner, title: "承認制企画")

      [project, manual_project].each do |target|
        expect { post join_business_project_path(target) }.not_to change { membership_rows }
        expect(response).to redirect_to(business_join_path)
      end
    end

    it "利用開始後に戻った先は画面(GET)で、そこで参加ボタンを押すまで参加しない" do
      post business_community_permit_path(auto_community)
      expect { post business_join_path }.not_to change { membership_rows }
      expect(response).to redirect_to(business_community_path(auto_community))
    end
  end

  describe "サービス自体の確認(画面を通らない呼び出しにも効く)" do
    it "Business の利用資格が無ければ :business_required を返し、行を作らない" do
      CommunityCustomer.create!(community: community, customer: music_only)

      expect do
        expect(Business::Memberships::JoinCommunity.call(community: auto_community, customer: music_only)).to eq :business_required
        expect(Business::Memberships::JoinProject.call(project: project, customer: music_only)).to eq :business_required
      end.not_to change { membership_rows }
    end

    it "システム管理者が管理権限を付けた運営者は、Business ドメインが無くても従来どおり運営中の画面を開ける" do
      co_operator = create(:customer, domain_name: "music", onboarding_done: true)
      CommunityOwner.create!(community: community, customer: co_operator)
      sign_in co_operator

      get business_community_path(community)
      expect(response).to have_http_status(:ok)
      get business_project_path(project)
      expect(response).to have_http_status(:ok)
      get business_permits_path(community)
      expect(response).to have_http_status(:ok)

      # 運営していないコミュニティは、ほかの人と同じく利用開始へ案内する。
      get business_community_path(auto_community)
      expect(response).to redirect_to(business_join_path)
    end

    describe "音楽だけの運営者・プロジェクト管理者の例外は、自分の管理対象だけに効く" do
      let(:other_owner) { create(:customer, domain_name: "business", onboarding_done: true) }
      let(:other_community) { create(:community, owner: other_owner, domain: business_domain, join_approval_mode: :auto) }
      let(:other_project) { Project.create!(community: other_community, customer: other_owner, title: "別コミュニティの企画", join_approval_mode: :auto) }

      before { CommunityCustomer.create!(community: other_community, customer: other_owner) }

      it "運営者: 別コミュニティ・そのプロジェクトは開けず、参加・申請の POST でも行を作らない" do
        co_operator = create(:customer, domain_name: "music", onboarding_done: true)
        CommunityOwner.create!(community: community, customer: co_operator)
        sign_in co_operator

        [business_community_path(other_community), business_project_path(other_project)].each do |path|
          get path
          expect(response).to redirect_to(business_join_path), path
        end
        expect do
          post business_community_permit_path(other_community)
          post join_business_project_path(other_project)
          # 自分が運営するコミュニティでも、一般の参加申請(参加行の作成)は利用資格が必要。
          post business_community_permit_path(community)
        end.not_to change { membership_rows }
      end

      it "プロジェクト作成者: 自分のプロジェクトだけ開け、同じコミュニティのほかのプロジェクトには参加できない" do
        creator = create(:customer, domain_name: "music", onboarding_done: true)
        CommunityCustomer.create!(community: community, customer: creator)
        own = Project.create!(community: community, customer: creator, title: "自分の企画")
        sibling = Project.create!(community: community, customer: owner, title: "隣の企画", join_approval_mode: :auto)
        sign_in creator

        get business_project_path(own)
        expect(response).to have_http_status(:ok)
        get business_project_path(sibling)
        expect(response).to redirect_to(business_join_path)
        expect { post join_business_project_path(sibling) }.not_to change { membership_rows }
        # 親コミュニティの画面は運営者ではないため、利用資格が無ければ開けない。
        get business_community_path(community)
        expect(response).to redirect_to(business_join_path)
      end

      it "プロジェクト作成者でも、親コミュニティから外れたり停止されたりすると例外は効かない" do
        creator = create(:customer, domain_name: "music", onboarding_done: true)
        CommunityCustomer.create!(community: community, customer: creator)
        own = Project.create!(community: community, customer: creator, title: "自分の企画")
        sign_in creator

        Business::Memberships::RevokeCommunityAccess.call(community: community, customer: creator)
        get business_project_path(own)
        expect(response).to redirect_to(business_join_path)

        CommunityCustomer.create!(community: community, customer: creator)
        Business::Memberships::RevokeCommunityAccess.call(community: community, customer: creator, suspend: true, actor: owner)
        get business_project_path(own)
        expect(response).to redirect_to(business_join_path)
        expect(creator.reload.business_project_participant?(own)).to be false
      end
    end

    it "システム管理者は Business ドメインが無くても従来どおり(運営者としての扱いを変えない)" do
      admin = create(:customer, domain_name: "music", is_owner: :admin, onboarding_done: true)
      sign_in admin

      get business_community_path(community)
      expect(response).to have_http_status(:ok)
      get business_project_path(project)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "利用資格がある人は従来どおり" do
    let(:business_member) { create(:customer, domain_name: "business", onboarding_done: true) }

    it "Business 利用者は申請・自動参加できる(GET では何も起きない)" do
      sign_in business_member

      expect { get business_community_path(auto_community) }.not_to change { membership_rows }
      expect { post business_community_permit_path(auto_community) }.to change(CommunityCustomer, :count).by(1)
      expect { post business_community_permit_path(community) }.to change(Permit, :count).by(1)
    end

    it "停止中の人は利用資格があっても参加・申請できない(停止の扱いは変えない)" do
      sign_in business_member
      CommunityAccessSuspension.create!(community: auto_community, customer: business_member)

      expect { post business_community_permit_path(auto_community) }.not_to change { membership_rows }
      expect(flash[:alert]).to eq "このコミュニティへのアクセスは停止されています"
    end
  end

  it "音楽側の資格・所属データは変えない(音楽コミュニティの参加・音楽トップ)" do
    music_community = create(:community, domain: music_domain)
    CommunityCustomer.create!(community: music_community, customer: music_only)
    sign_in music_only

    get business_community_path(community)
    get root_path

    expect(response).to have_http_status(:ok)
    expect(music_only.reload.domains.pluck(:name)).to eq ["music"]
    expect(music_only.community_customers.pluck(:community_id)).to eq [music_community.id]
  end
end
