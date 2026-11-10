require "rails_helper"

# 承認待ちの参加申請は、承認できる人の通知ベル・通知一覧と、メンバー管理の承認待ち一覧の両方に出す。
RSpec.describe "参加申請の通知とメンバー管理の承認待ち一覧", type: :request do
  def bell_count(customer)
    customer.passive_notifications.for_business.shown_in_app.where(checked: false).count
  end

  def request_notifications(applicant, recipient, action)
    Notification.unscoped.where(visitor_id: applicant.id, visited_id: recipient.id, action: action)
  end

  def body_html
    Nokogiri::HTML(response.body)
  end

  describe "Business コミュニティ(手動承認)" do
    let(:business_domain) { Domain.find_or_create_by!(name: "business") }
    let(:owner) { create(:customer, domain_name: "business") }
    let(:co_owner) { create(:customer, domain_name: "business") }
    let(:member) { create(:customer, domain_name: "business") }
    let(:applicant) { create(:customer, domain_name: "business", name: "申請するひと") }
    let(:community) { create(:community, owner: owner, domain: business_domain) }

    before do
      [owner, co_owner, member].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
      CommunityOwner.create!(community: community, customer: co_owner)
    end

    def request_join
      sign_in applicant
      post business_community_permit_path(community)
    end

    def permits_page_names(viewer)
      sign_in viewer
      get business_permits_path(community)
      body_html.css("#join-requests .ba-person__name").map(&:text)
    end

    it "オーナーと運営者のベル・通知一覧に出て、通知からメンバー管理の承認待ち欄へ進める" do
      request_join

      [owner, co_owner].each do |approver|
        expect(bell_count(approver)).to eq 1
        sign_in approver
        get business_notifications_path
        link = body_html.at_css("a.ba-notification[href*='/permits']")
        expect(link["href"]).to eq business_permits_path(community, anchor: "join-requests")
        expect(link.text).to include("参加申請", community.name)

        get link["href"]
        expect(response).to have_http_status(:ok)
        expect(body_html.css("#join-requests .ba-person__name").map(&:text)).to eq ["申請するひと"]
      end
    end

    it "承認権限のない参加者には通知しない" do
      request_join

      expect(request_notifications(applicant, member, "request")).to be_empty
    end

    it "画面内の通知をオフにしていても、メンバー管理には承認待ちとして出る" do
      BusinessNotificationSetting.create!(customer: owner, email_enabled: false, in_app_enabled: false)
      request_join

      expect(bell_count(owner)).to eq 0
      expect(request_notifications(applicant, owner, "request").first).to be_hidden_in_app
      expect(permits_page_names(owner)).to eq ["申請するひと"]
    end

    it "連打・取り消し後の再申請でも、承認する人ごとの通知は1件のまま未読に戻る" do
      3.times { request_join }
      delete business_community_permit_path(community)
      request_join

      expect(request_notifications(applicant, owner, "request").count).to eq 1
      expect(request_notifications(applicant, co_owner, "request").count).to eq 1
      expect(bell_count(owner)).to eq 1
    end

    it "承認すると承認待ち一覧から消え、通知はベルに残らない" do
      request_join
      sign_in owner
      post business_community_community_customers_path(community, customer_id: applicant.id, return_to: "permits")

      expect(permits_page_names(owner)).to be_empty
      expect(bell_count(owner)).to eq 0
      expect(bell_count(co_owner)).to eq 0
      expect(request_notifications(applicant, owner, "request").count).to eq 1
    end

    it "運営者が却下すると承認待ち一覧から消える" do
      request_join
      sign_in co_owner
      delete business_community_permit_path(community, customer_id: applicant.id, return_to: "permits")

      expect(permits_page_names(co_owner)).to be_empty
      expect(bell_count(owner)).to eq 0
    end

    it "申請者が取り消すと承認待ち一覧から消える" do
      request_join
      delete business_community_permit_path(community)

      expect(permits_page_names(owner)).to be_empty
      expect(bell_count(owner)).to eq 0
    end

    it "承認権限のない参加者はメンバー管理を開けない(既存の権限を維持)" do
      request_join

      sign_in member
      get business_permits_path(community)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "Business プロジェクト(手動承認)" do
    let(:business_domain) { Domain.find_or_create_by!(name: "business") }
    let(:owner) { create(:customer, domain_name: "business") }
    let(:creator) { create(:customer, domain_name: "business") }
    let(:applicant) { create(:customer, domain_name: "business", name: "プロジェクト申請者") }
    let(:community) { create(:community, owner: owner, domain: business_domain, join_approval_mode: :auto) }
    let(:project) { Project.create!(community: community, customer: creator, title: "LP制作") }

    before do
      [owner, creator, applicant].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    end

    def request_join
      sign_in applicant
      post join_business_project_path(project)
    end

    def members_page_names(viewer)
      sign_in viewer
      get members_business_project_path(project)
      body_html.css("#join-requests .ba-person__name").map(&:text)
    end

    it "コミュニティのオーナーとプロジェクト作成者のベルに出て、通知からメンバー管理へ進める" do
      request_join

      [owner, creator].each do |approver|
        expect(bell_count(approver)).to eq 1
        sign_in approver
        get business_notifications_path
        link = body_html.at_css("a.ba-notification[href*='/members']")
        expect(link["href"]).to eq members_business_project_path(project, anchor: "join-requests")
        expect(link.text).to include("LP制作")
        expect(members_page_names(approver)).to eq ["プロジェクト申請者"]
      end
    end

    it "画面内の通知をオフにしていても、メンバー管理には承認待ちとして出る" do
      BusinessNotificationSetting.create!(customer: creator, email_enabled: false, in_app_enabled: false)
      request_join

      expect(bell_count(creator)).to eq 0
      expect(members_page_names(creator)).to eq ["プロジェクト申請者"]
    end

    it "連打・取り消し後の再申請でも通知は1件のまま" do
      2.times { request_join }
      delete cancel_request_business_project_path(project)
      request_join

      expect(request_notifications(applicant, creator, "project_request").count).to eq 1
      expect(bell_count(creator)).to eq 1
    end

    it "承認・却下・取り消しのあとは承認待ち一覧に残らず、ベルにも残らない" do
      request_join
      sign_in creator
      post approve_business_project_join_request_path(project, ProjectJoinRequest.last)
      expect(members_page_names(creator)).to be_empty
      expect(bell_count(creator)).to eq 0

      other = create(:customer, domain_name: "business", name: "却下されるひと")
      CommunityCustomer.create!(community: community, customer: other)
      sign_in other
      post join_business_project_path(project)
      sign_in owner
      delete reject_business_project_join_request_path(project, ProjectJoinRequest.find_by(customer: other))
      expect(members_page_names(owner)).to be_empty
      expect(bell_count(owner)).to eq 0

      another = create(:customer, domain_name: "business")
      CommunityCustomer.create!(community: community, customer: another)
      sign_in another
      post join_business_project_path(project)
      delete cancel_request_business_project_path(project)
      expect(members_page_names(owner)).to be_empty
      expect(bell_count(owner)).to eq 0
    end
  end

  describe "音楽コミュニティ" do
    let!(:owner) { create(:customer) }
    let(:applicant) { create(:customer, name: "音楽の申請者") }
    let!(:community) { create(:community, owner: owner) }
    let!(:chat_room) { create(:chat_room) }
    let!(:owner_chat_room_customer) { create(:chat_room_customer, customer_id: owner.id, chat_room_id: chat_room.id, community_id: community.id) }

    def request_join
      sign_in applicant
      post public_community_permits_path(community)
    end

    def permits_page_names
      sign_in owner
      get public_permits_path(community)
      body_html.css(".permit-table-body td:nth-child(3)").map { |td| td.text.strip }
    end

    it "オーナーの通知に出て、通知から承認待ち一覧へ進める" do
      request_join

      expect(owner.passive_notifications.where(action: "request", checked: false).count).to eq 1
      sign_in owner
      get public_notifications_path
      link = body_html.at_css("a.notification-permits-link")
      expect(link["href"]).to eq public_permits_path(community)
      expect(permits_page_names).to eq ["音楽の申請者"]
    end

    it "連打しても申請と通知は1件だけで、取り消し後の再申請でも通知は増えない" do
      3.times { request_join }
      expect(Permit.where(community: community, customer: applicant).count).to eq 1

      delete public_community_permits_path(community)
      delete public_community_permits_path(community)
      request_join

      expect(Permit.where(community: community, customer: applicant).count).to eq 1
      expect(request_notifications(applicant, owner, "request").count).to eq 1
      expect(request_notifications(applicant, owner, "request_cancel").count).to eq 1
      expect(permits_page_names).to eq ["音楽の申請者"]
    end

    it "承認・取り消しのあとは承認待ち一覧に残らない" do
      request_join
      sign_in owner
      post public_community_community_customers_path(community, permit_id: Permit.last.id)
      expect(permits_page_names).to be_empty
      expect(owner.passive_notifications.where(action: "request", checked: false)).to be_empty

      other = create(:customer)
      sign_in other
      post public_community_permits_path(community)
      delete public_community_permits_path(community)
      expect(permits_page_names).to be_empty
    end
  end
end
