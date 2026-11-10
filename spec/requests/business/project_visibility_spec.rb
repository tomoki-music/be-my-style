require "rails_helper"

# プロジェクトの公開範囲(通常公開 / 限定公開)。限定公開は一覧・検索から除くだけで、
# 直接URL・招待用URLからの閲覧、参加申請・承認の条件は通常公開と同じにする。
RSpec.describe "Business プロジェクトの公開範囲", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:owner) { create(:customer, domain_name: "business", name: "運営者", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "公開範囲コミュニティ") }
  let(:member) { create(:customer, domain_name: "business", name: "参加者さん", onboarding_done: true) }
  let(:viewer) { create(:customer, domain_name: "business", name: "未参加の会員さん", onboarding_done: true) }
  let(:outsider) { create(:customer, domain_name: "business", name: "コミュニティ外さん", onboarding_done: true) }
  let!(:listed) { Project.create!(community: community, customer: owner, title: "通常公開の企画", description: "誰でも探せます") }
  let!(:unlisted) do
    Project.create!(community: community, customer: owner, title: "限定公開の企画", description: "URLを知る人だけ", visibility: :unlisted)
  end

  before do
    [owner, member, viewer].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    [listed, unlisted].each { |project| ProjectMember.create!(project: project, customer: member) }
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def listed_titles
    doc.css(".ba-project-card__title").map { |node| node.text.strip }
  end

  describe "既定値" do
    it "既存・新規のプロジェクトは通常公開として扱う" do
      expect(Project.new.visibility).to eq "listed"
      expect(listed.reload).to be_visibility_listed
      expect(Project.listed).to contain_exactly(listed)
    end
  end

  describe "通常の閲覧画面の一覧" do
    it "NAKAMAのTOP・プロジェクト一覧(探す)・コミュニティ詳細の一覧に、通常公開だけを出す" do
      sign_in member

      get business_root_path
      expect(listed_titles).to eq ["通常公開の企画"]
      expect(doc.at_css("#my-projects .ba-count").text).to eq "1件"

      get business_projects_path
      expect(listed_titles).to eq ["通常公開の企画"]

      get business_projects_path(community_id: community.id)
      expect(listed_titles).to eq ["通常公開の企画"]

      get business_community_path(community)
      expect(listed_titles).to eq ["通常公開の企画"]
      expect(doc.at_css("#community-projects-title .ba-count").text).to eq "1件"

      expect(response.body).not_to include("限定公開の企画")
    end

    it "運営者・作成者・システム管理者の一覧でも限定公開は出さない(管理側の「プロジェクト管理」には出す)" do
      sign_in owner
      [business_root_path, business_projects_path, business_community_path(community)].each do |path|
        get path
        expect(listed_titles).to eq(["通常公開の企画"]), path
      end

      get business_community_project_management_path(community)
      row = doc.css(".ba-row").find { |node| node.text.include?("限定公開の企画") }
      expect(row).to be_present
      expect(row.at_css(".ba-status--unlisted").text.strip).to eq "限定公開"
      expect(row.at_css("a[href='#{edit_business_project_path(unlisted)}']")).to be_present
      expect(doc.css(".ba-row").find { |node| node.text.include?("通常公開の企画") }.at_css(".ba-status--unlisted")).to be_nil

      admin = create(:customer, domain_name: "business", is_owner: :admin, onboarding_done: true)
      sign_in admin
      get business_projects_path
      expect(listed_titles).to eq ["通常公開の企画"]
    end

    it "音楽側のログイン後ホームのプロジェクト一覧にも出さない" do
      expect(Homes::MyProjects.call(member).projects.map(&:title)).to eq ["通常公開の企画"]
    end
  end

  describe "直接URL・招待用URLからの閲覧" do
    it "参加者は限定公開の詳細を開け、スレッド・メンバーも見られる。限定公開のしるしを出す" do
      sign_in member
      get business_project_path(unlisted)

      expect(response).to have_http_status(:ok)
      expect(doc.at_css("h1").text).to eq "限定公開の企画"
      expect(doc.at_css(".ba-profile__badges .ba-status--unlisted").text.strip).to eq "限定公開"
      expect(doc.at_css("#threads")).to be_present
      expect(doc.at_css("[data-share-url]")["value"]).to eq "http://localhost:3000/business/projects/#{unlisted.id}"
    end

    it "通常公開には限定公開のしるしを出さない" do
      sign_in member
      get business_project_path(listed)

      expect(doc.at_css(".ba-status--unlisted")).to be_nil
    end

    it "コミュニティ参加者で未参加なら、通常公開と同じく概要と参加申請だけを出す" do
      sign_in viewer
      get business_project_path(unlisted)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("限定公開の企画", "参加を申請する", "参加者限定")
      expect(doc.at_css("#threads")).to be_nil
    end

    it "承認制: 申請すると承認待ちになり、承認されるまで内部を見られない。承認後は見られる" do
      sign_in viewer
      expect { post join_business_project_path(unlisted) }.to change(ProjectJoinRequest, :count).by(1)
      expect(flash[:notice]).to eq "プロジェクトへ参加申請しました"
      expect(ProjectMember.exists?(project: unlisted, customer: viewer)).to be false

      get business_project_path(unlisted)
      expect(doc.at_css("#threads")).to be_nil

      sign_in owner
      get members_business_project_path(unlisted)
      expect(response.body).to include("未参加の会員さん")

      request_record = unlisted.project_join_requests.find_by!(customer: viewer)
      post approve_business_project_join_request_path(unlisted, request_record)
      expect(ProjectMember.exists?(project: unlisted, customer: viewer)).to be true

      sign_in viewer
      get business_project_path(unlisted)
      expect(doc.at_css("#threads")).to be_present
    end

    it "自動承認なら、通常公開と同じくその場で参加できる" do
      unlisted.update!(join_approval_mode: :auto)
      sign_in viewer

      post join_business_project_path(unlisted)

      expect(flash[:notice]).to eq "プロジェクトに参加しました！"
      expect(ProjectMember.exists?(project: unlisted, customer: viewer)).to be true
    end

    it "親コミュニティ未参加なら開けず(参加もできず)、コミュニティの参加案内へ戻す" do
      sign_in outsider

      get business_project_path(unlisted)
      expect(response).to redirect_to(business_community_path(community))

      expect { post join_business_project_path(unlisted) }.not_to change { [ProjectJoinRequest.count, ProjectMember.count] }
      expect(response).to redirect_to(business_community_path(community))
    end

    it "未ログインならログインへ案内し、中身を出さない" do
      get business_project_path(unlisted)

      expect(response).to redirect_to(new_business_customer_session_url)
    end

    it "招待用URLから新規登録した人は、コミュニティ参加後に限定公開のプロジェクトへ案内される" do
      community.update!(join_approval_mode: :auto)
      get business_project_path(unlisted)
      post business_customer_registration_path, params: {
        customer: { email: "unlisted-invite@example.com", password: "password", password_confirmation: "password", name: "新しい人" }
      }
      newcomer = Customer.find_by!(email: "unlisted-invite@example.com")
      expect(newcomer.business_signup_invitation).to have_attributes(target_type: "Project", target_id: unlisted.id)

      get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
      get onboarding_step1_path
      get onboarding_step2_path
      post business_community_permit_path(community)
      get onboarding_step3_path
      patch onboarding_complete_path

      expect(response).to redirect_to(business_project_path(unlisted))
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(doc.at_css("h1").text).to eq "限定公開の企画"
    end
  end

  describe "公開範囲の切り替え" do
    it "編集権限のある人は、限定公開の詳細から編集画面を開き、案内を見て通常公開へ戻せる。戻すと一覧に再表示される" do
      sign_in owner
      get business_project_path(unlisted)
      expect(doc.at_css(".ba-manage-bar a[href='#{edit_business_project_path(unlisted)}'], a[href='#{edit_business_project_path(unlisted)}']")).to be_present

      get edit_business_project_path(unlisted)
      expect(response).to have_http_status(:ok)
      expect(doc.at_css("select#project_visibility option[selected]")["value"]).to eq "unlisted"
      expect(doc.css("select#project_visibility option").map { |o| [o.text, o["value"]] }).to eq [%w[通常公開 listed], %w[限定公開 unlisted]]
      expect(doc.at_css("#project-visibility-help").text).to include("一覧・検索には表示されません。URLからの閲覧には既存の閲覧条件が適用されます")

      patch business_project_path(unlisted), params: { project: { visibility: "listed" } }
      expect(response).to redirect_to(business_project_path(unlisted))
      expect(unlisted.reload).to be_visibility_listed

      sign_in member
      get business_projects_path
      expect(listed_titles).to contain_exactly("通常公開の企画", "限定公開の企画")
      get business_community_path(community)
      expect(listed_titles).to contain_exactly("通常公開の企画", "限定公開の企画")
      get business_root_path
      expect(listed_titles).to contain_exactly("通常公開の企画", "限定公開の企画")
    end

    it "通常公開から限定公開にすると、一覧から消える" do
      sign_in owner
      patch business_project_path(listed), params: { project: { visibility: "unlisted" } }
      expect(listed.reload).to be_visibility_unlisted

      sign_in member
      get business_projects_path
      expect(listed_titles).to be_empty
    end

    it "プロジェクトの作成者も既存の編集権限で切り替えられる" do
      creator = create(:customer, domain_name: "business", onboarding_done: true)
      CommunityCustomer.create!(community: community, customer: creator)
      own = Project.create!(community: community, customer: creator, title: "作成者の企画")
      sign_in creator

      patch business_project_path(own), params: { project: { visibility: "unlisted" } }

      expect(own.reload).to be_visibility_unlisted
    end

    it "編集権限のない参加者は切り替えられず、編集画面も開けない" do
      sign_in member

      get edit_business_project_path(unlisted)
      expect(response).to redirect_to(business_project_path(unlisted))

      patch business_project_path(unlisted), params: { project: { visibility: "listed" } }
      expect(response).to redirect_to(business_project_path(unlisted))
      expect(unlisted.reload).to be_visibility_unlisted
    end

    it "選択肢にない値は受け付けず、保存済みの公開範囲を残す(ほかの項目は保存する)" do
      sign_in owner

      patch business_project_path(unlisted), params: { project: { visibility: "secret", title: "名前だけ変更" } }

      expect(response).to redirect_to(business_project_path(unlisted))
      expect(unlisted.reload).to have_attributes(visibility: "unlisted", title: "名前だけ変更")
    end

    it "公開範囲を送らない更新では、公開範囲を変えない" do
      sign_in owner

      patch business_project_path(unlisted), params: { project: { title: "改名" } }

      expect(unlisted.reload).to have_attributes(visibility: "unlisted", title: "改名")
    end
  end
end
