require 'rails_helper'

RSpec.describe "Business::Communities", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer) }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:customer) { create(:customer) }

  before do
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
    sign_in customer
  end

  describe "GET /business/communities/:id (show) の退会済みメンバー表示" do
    let(:withdrawn_member) { create(:customer, name: "退会済み次郎", is_deleted: true) }

    before do
      CommunityCustomer.find_or_create_by!(customer: withdrawn_member, community: community)
    end

    it '退会済みメンバーがメンバー一覧に表示されないこと' do
      get business_community_path(community)

      expect(response.body).to include(customer.name)
      expect(response.body).not_to include(withdrawn_member.name)
    end

    it '参加人数から退会済みメンバーが除かれること' do
      get business_community_path(community)

      expect(response.body).to include("#{community.active_customers.count}人")
      expect(community.customers.count).to eq(community.active_customers.count + 1)
    end

    it '退会済みメンバーのCommunityCustomerレコード自体は削除されないこと' do
      get business_community_path(community)

      expect(CommunityCustomer.exists?(community: community, customer: withdrawn_member)).to eq true
    end
  end

  describe "GET /business/communities/:id (show) の退会済みオーナー表示" do
    before { owner.update!(is_deleted: true) }

    it 'オーナー名・プロフィールリンク・役職バッジを表示しないこと' do
      get business_community_path(community)

      expect(response.body).to include("退会済みユーザー")
      expect(response.body).not_to include(owner.name)
      expect(response.body).not_to include(%(href="#{business_customer_path(owner)}"))
    end
  end

  describe "GET /business/communities/:id/permits (承認待ち一覧)" do
    let(:applicant) { create(:customer, name: "申請太郎") }
    let(:withdrawn_applicant) { create(:customer, name: "退会済み申請花子", is_deleted: true) }
    let!(:active_permit) { create(:permit, community: community, customer: applicant) }
    let!(:withdrawn_permit) { create(:permit, community: community, customer: withdrawn_applicant) }

    before { sign_in owner }

    it '退会済み申請者が一覧に表示されないこと' do
      get business_permits_path(community)

      expect(response.body).to include("申請太郎")
      expect(response.body).not_to include("退会済み申請花子")
    end
  end

  describe "通常画面とメンバー管理画面の分離(参加申請)" do
    let(:applicant) { create(:customer, name: "申請太郎") }
    let(:withdrawn_applicant) { create(:customer, name: "退会済み申請花子", is_deleted: true) }

    def doc
      Nokogiri::HTML(response.body)
    end

    def manage_bar
      doc.at_css("nav.manage-bar")
    end

    shared_examples "通常画面には導線だけを出し、承認・拒否はメンバー管理画面で行う" do
      it "通常画面に承認・拒否・設定フォームを出さず、管理メニューに承認待ち件数を出す" do
        create(:permit, community: community, customer: applicant)
        create(:permit, community: community, customer: withdrawn_applicant)

        get business_community_path(community)

        expect(response).to have_http_status(:ok)
        expect(manage_bar).to be_present
        expect(manage_bar.at_css(%(a[href="#{edit_business_community_path(community)}"])).text).to include("編集")
        member_link = manage_bar.at_css(%(a[href="#{business_permits_path(community)}"]))
        expect(member_link.text).to include("メンバー管理")
        expect(member_link.at_css(".manage-bar__badge").text).to eq "1"
        expect(manage_bar.at_css(%([aria-current="page"])).text).to eq "通常画面"

        expect(doc.css(".permit-card")).to be_empty
        expect(doc.at_css(%(a[href*="community_customers"]))).to be_nil
        expect(doc.at_css(%(a[href*="access_suspensions"]))).to be_nil
        expect(doc.at_css(%(form[action="#{business_community_path(community)}"]))).to be_nil
        expect(doc.at_css(%(form[action="#{business_community_plan_trial_path(community)}"]))).to be_nil
        expect(doc.at_css(".danger-zone")).to be_nil
        expect(response.body).not_to include("申請太郎")
      end

      it "メンバー管理画面に申請者(退会済みを除く)と承認・却下の操作を出し、通常画面へ戻れる" do
        create(:permit, community: community, customer: applicant)
        create(:permit, community: community, customer: withdrawn_applicant)

        get business_permits_path(community)

        expect(response).to have_http_status(:ok)
        expect(doc.css(".permit-card .membership-admin__name").map(&:text)).to eq ["申請太郎"]
        expect(doc.at_css(%(a[href="#{business_community_community_customers_path(community_id: community.id, customer_id: applicant.id, return_to: "permits")}"]))).to be_present
        expect(doc.at_css(%(a[href="#{business_community_permit_path(community, customer_id: applicant.id, return_to: "permits")}"]))).to be_present
        expect(manage_bar.at_css(%(a[href="#{business_community_path(community)}"])).text.strip).to eq "通常画面"
        expect(manage_bar.at_css(%([aria-current="page"])).text).to eq "メンバー管理"
      end
    end

    shared_examples "管理メニューも申請者情報も表示しない" do
      it "申請があっても管理導線・申請者名を出さない" do
        create(:permit, community: community, customer: applicant)

        get business_community_path(community)

        expect(response).to have_http_status(:ok)
        expect(manage_bar).to be_nil
        expect(doc.at_css(%(a[href="#{edit_business_community_path(community)}"]))).to be_nil
        expect(doc.at_css(%(a[href="#{business_permits_path(community)}"]))).to be_nil
        expect(response.body).not_to include("申請太郎")
      end
    end

    context "オーナー" do
      before { sign_in owner }

      include_examples "通常画面には導線だけを出し、承認・拒否はメンバー管理画面で行う"
    end

    context "管理権限を付与された CommunityOwner" do
      before do
        co_owner = create(:customer)
        CommunityOwner.create!(community: community, customer: co_owner)
        sign_in co_owner
      end

      include_examples "通常画面には導線だけを出し、承認・拒否はメンバー管理画面で行う"
    end

    context "Customer の is_owner が admin" do
      before { sign_in create(:customer, is_owner: :admin) }

      include_examples "通常画面には導線だけを出し、承認・拒否はメンバー管理画面で行う"
    end

    context "一般参加者" do
      include_examples "管理メニューも申請者情報も表示しない"
    end

    context "非参加者" do
      before { sign_in create(:customer) }

      include_examples "管理メニューも申請者情報も表示しない"
    end

    context "本人が申請中" do
      before { sign_in applicant }

      it "申請中の表示と申請取消の操作を残し、他の申請者の情報は出さない" do
        create(:permit, community: community, customer: applicant)
        create(:permit, community: community, customer: create(:customer, name: "別の申請者"))

        get business_community_path(community)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("承認待ち")
        expect(response.body).to include("申請を取り消す")
        expect(manage_bar).to be_nil
        expect(response.body).not_to include("別の申請者")
      end
    end
  end

  describe "編集・更新・削除の権限" do
    let(:co_owner) { create(:customer) }
    let(:admin_customer) { create(:customer, is_owner: :admin) }
    let(:outsider) { create(:customer) }

    before { CommunityOwner.create!(community: community, customer: co_owner) }

    def update_name(name, extra = {})
      patch business_community_path(community), params: { community: { name: name }.merge(extra) }
    end

    it "オーナーは編集画面を開き、更新できる" do
      sign_in owner

      get edit_business_community_path(community)
      expect(response).to have_http_status(:ok)

      update_name("オーナー更新")
      expect(community.reload.name).to eq "オーナー更新"
    end

    it "管理権限を付与された CommunityOwner は更新できるが削除はできない" do
      sign_in co_owner

      update_name("共同管理者更新")
      expect(community.reload.name).to eq "共同管理者更新"

      expect { delete business_community_path(community) }.not_to change(Community, :count)
      expect(flash[:alert]).to eq "このコミュニティを削除する権限がありません。"
    end

    it "オーナーと管理者は削除できる" do
      sign_in owner
      expect { delete business_community_path(community) }.to change(Community, :count).by(-1)

      other = create(:community, owner: owner, domain: business_domain)
      sign_in admin_customer
      expect { delete business_community_path(other) }.to change(Community, :count).by(-1)
    end

    [
      ["一般メンバー", :customer],
      ["非参加者", :outsider]
    ].each do |label, actor|
      context label do
        before { sign_in public_send(actor) }

        it "編集画面・承認待ち一覧を開けない" do
          get edit_business_community_path(community)
          expect(response).to redirect_to(business_community_path(community))

          get business_permits_path(community)
          expect(response).to redirect_to(business_community_path(community))
        end

        it "直接リクエストしても更新・削除できない" do
          original_name = community.name

          update_name("乗っ取り")
          expect(response).to redirect_to(business_community_path(community))
          expect(community.reload.name).to eq original_name

          expect { delete business_community_path(community) }.not_to change(Community, :count)
        end
      end
    end

    it "通常の更新エンドポイントからはお試し設定を変更できない(オーナーでも無視される)" do
      sign_in owner

      update_name("名前だけ変わる", plan_restrictions_waived: "1")

      expect(community.reload.name).to eq "名前だけ変わる"
      expect(community.plan_restrictions_waived).to eq false
    end

    it "権限のないユーザーが通常の更新エンドポイントでお試し設定を送っても変わらない" do
      sign_in customer

      update_name(community.name, plan_restrictions_waived: "1")

      expect(community.reload.plan_restrictions_waived).to eq false
    end

    it "他ドメインのコミュニティは Business 画面から更新できない" do
      music_community = create(:community, owner: owner)
      sign_in owner

      expect {
        patch business_community_path(music_community), params: { community: { name: "越境" } }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "タイムラインの閲覧範囲(コミュニティ参加者のみ)" do
    before { CommunityPost.create!(community: community, customer: owner, body: "参加者向けタイムラインの投稿") }

    it "非参加者には本文も投稿フォームも出さず、名称・紹介と参加導線だけを出す" do
      sign_in create(:customer)

      get business_community_path(community)

      expect(response.body).to include(community.name)
      expect(response.body).to include(community.introduction)
      expect(response.body).not_to include("参加者向けタイムラインの投稿")
      expect(response.body).not_to include("投稿する...")
      expect(response.body).to include("参加を申請する")
      expect(response.body).to include("コミュニティの参加者のみ閲覧できます")
    end

    it "参加者は閲覧できる" do
      member = create(:customer)
      CommunityCustomer.create!(customer: member, community: community)
      sign_in member

      get business_community_path(community)

      expect(response.body).to include("参加者向けタイムラインの投稿")
    end

    it "未ログインでは閲覧できない" do
      sign_out customer

      get business_community_path(community)

      expect(response).to redirect_to(new_customer_session_path)
    end
  end
end
