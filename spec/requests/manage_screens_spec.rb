require "rails_helper"

# コミュニティ / プロジェクトの「通常画面(参加者と共通)」「編集画面」「メンバー管理画面」の分離と、
# 管理画面への直接アクセス・別対象の指定に対するサーバー側の認可。
RSpec.describe "通常画面・編集画面・メンバー管理画面の分離", type: :request do
  def doc
    Nokogiri::HTML(response.body)
  end

  def manage_bar
    doc.at_css("nav.manage-bar")
  end

  def current_tab
    manage_bar.at_css(%([aria-current="page"])).text.strip
  end

  describe "Business プロジェクト" do
    let(:business_domain) { Domain.find_or_create_by!(name: "business") }
    let(:owner) { create(:customer, domain_name: "business") }
    let(:community) { create(:community, owner: owner, domain: business_domain) }
    let(:creator) { create(:customer, domain_name: "business") }
    let(:participant) { create(:customer, domain_name: "business") }
    let(:applicant) { create(:customer, name: "申請次郎", domain_name: "business") }
    let(:community_member) { create(:customer, domain_name: "business") }
    let!(:project) { Project.create!(community: community, customer: creator, title: "A社サイト制作", description: "概要です", join_approval_mode: :manual) }

    before do
      [owner, creator, participant, applicant, community_member].each do |customer|
        CommunityCustomer.find_or_create_by!(community: community, customer: customer)
      end
      ProjectMember.create!(project: project, customer: participant)
      ProjectJoinRequest.create!(project: project, customer: applicant)
    end

    [
      ["コミュニティのオーナー", :owner],
      ["プロジェクト作成者", :creator]
    ].each do |label, role|
      context label do
        before { sign_in public_send(role) }

        it "通常画面は参加者と同じ内容で、管理メニューの導線だけを出す" do
          get business_project_path(project)

          expect(response).to have_http_status(:ok)
          expect(current_tab).to eq "通常画面"
          expect(manage_bar.at_css(%(a[href="#{edit_business_project_path(project)}"])).text.strip).to eq "編集"
          expect(manage_bar.at_css(%(a[href="#{members_business_project_path(project)}"]) + " .manage-bar__badge").text).to eq "1"
          expect(doc.at_css("#threads")).to be_present
          expect(doc.at_css(%(form[action="#{business_project_path(project)}"]))).to be_nil
          expect(doc.at_css(%(a[href*="join_requests"]))).to be_nil
          expect(doc.at_css(%(a[href*="access_suspensions"]))).to be_nil
          expect(response.body).not_to include("申請次郎")
        end

        it "編集画面に保存・キャンセル・通常画面への導線があり、保存すると通常画面へ戻る" do
          get edit_business_project_path(project)

          expect(response).to have_http_status(:ok)
          expect(current_tab).to eq "編集"
          expect(doc.at_css(%(form[action="#{business_project_path(project)}"] input[type="submit"][value="保存する"]))).to be_present
          expect(doc.at_css(%(.form-actions a[href="#{business_project_path(project)}"])).text).to eq "キャンセル"
          expect(manage_bar.at_css(%(a[href="#{business_project_path(project)}"])).text.strip).to eq "通常画面"
          expect(manage_bar.at_css(%(a[href="#{members_business_project_path(project)}"]))).to be_present
          expect(doc.at_css("#threads")).to be_nil

          patch business_project_path(project), params: { project: { title: "A社サイト制作（改）" } }
          expect(response).to redirect_to(business_project_path(project))
          expect(flash[:notice]).to eq "更新しました！"
          expect(project.reload.title).to eq "A社サイト制作（改）"
        end

        it "メンバー管理画面で承認・却下でき、通常画面と編集画面へ戻れる" do
          get members_business_project_path(project)

          expect(response).to have_http_status(:ok)
          expect(current_tab).to eq "メンバー管理"
          expect(manage_bar.at_css(%(a[href="#{business_project_path(project)}"]))).to be_present
          expect(manage_bar.at_css(%(a[href="#{edit_business_project_path(project)}"]))).to be_present
          expect(response.body).to include("申請次郎")
        end

        it "更新で所属コミュニティは変えられない" do
          other = create(:community, owner: owner, domain: business_domain)

          patch business_project_path(project), params: { project: { title: "移動", community_id: other.id } }

          expect(project.reload.community_id).to eq community.id
        end
      end
    end

    [
      ["承認済みの参加者", :participant],
      ["承認待ちの申請者", :applicant],
      ["プロジェクト未参加のコミュニティ参加者", :community_member]
    ].each do |label, role|
      context label do
        before { sign_in public_send(role) }

        it "通常画面に管理メニュー・管理リンクを出さない" do
          get business_project_path(project)

          expect(response).to have_http_status(:ok)
          expect(manage_bar).to be_nil
          expect(doc.at_css(%(a[href="#{edit_business_project_path(project)}"]))).to be_nil
          expect(doc.at_css(%(a[href="#{members_business_project_path(project)}"]))).to be_nil
        end

        it "編集・メンバー管理を URL で直接開けず、更新・承認・停止もできない" do
          get edit_business_project_path(project)
          expect(response).to redirect_to(business_project_path(project))

          get members_business_project_path(project)
          expect(response).to redirect_to(business_project_path(project))

          patch business_project_path(project), params: { project: { title: "乗っ取り" } }
          expect(project.reload.title).to eq "A社サイト制作"

          request = project.project_join_requests.first
          post approve_business_project_join_request_path(project, request)
          expect(ProjectJoinRequest.exists?(request.id)).to eq true

          post business_project_access_suspensions_path(project, customer_id: participant.id)
          expect(project.project_access_suspensions).to be_empty
        end
      end
    end

    it "承認待ちの申請者には参加状態と申請取消の操作を残す" do
      sign_in applicant

      get business_project_path(project)

      expect(response.body).to include("承認待ち")
      expect(doc.at_css(%(a[href="#{cancel_request_business_project_path(project)}"]))).to be_present
    end

    it "別プロジェクトの申請 ID を自分のプロジェクトの URL で承認できない" do
      other_creator = create(:customer, domain_name: "business")
      CommunityCustomer.create!(community: community, customer: other_creator)
      other_project = Project.create!(community: community, customer: other_creator, title: "B社案件")
      outsider_request = ProjectJoinRequest.create!(project: other_project, customer: community_member)
      sign_in creator

      post approve_business_project_join_request_path(project, outsider_request)

      expect(flash[:alert]).to eq "参加申請が見つかりません。"
      expect(ProjectJoinRequest.exists?(outsider_request.id)).to eq true
      expect(other_project.project_members.where(customer: community_member)).to be_empty
    end
  end

  describe "Business プロジェクトの作成導線(通常画面には置かず、管理側に置く)" do
    let(:business_domain) { Domain.find_or_create_by!(name: "business") }
    let(:owner) { create(:customer, domain_name: "business") }
    let(:community) { create(:community, owner: owner, domain: business_domain) }
    let(:free_member) { create(:customer, domain_name: "business") }
    let(:outsider) { create(:customer, domain_name: "business") }
    let!(:project) { Project.create!(community: community, customer: owner, title: "既存プロジェクト") }

    before do
      CommunityCustomer.create!(community: community, customer: owner)
      CommunityCustomer.create!(community: community, customer: free_member)
    end

    def create_project(target, title: "新しい企画")
      post business_projects_path, params: { community_id: target.id, project: { title: title, description: "説明", community_id: target.id } }
    end

    def new_project_link
      doc.at_css(%(a[href="#{new_business_project_path(community_id: community.id)}"]))
    end

    context "運営者(オーナー)" do
      before { sign_in owner }

      it "通常画面に作成ボタンを出さず、既存のプロジェクト一覧は残し、管理メニューにプロジェクト管理を出す" do
        get business_community_path(community)

        expect(new_project_link).to be_nil
        expect(response.body).not_to include("＋ 作成")
        expect(doc.at_css(%(.project-grid a[href="#{business_project_path(project)}"]))).to be_present
        expect(manage_bar.css("a, [aria-current]").map { |el| el.text.strip.sub(/\d+\z/, "") }).to eq %w[通常画面 編集 メンバー管理 プロジェクト管理]
      end

      it "編集画面のプロジェクト管理セクションから作成画面へ進め、所属コミュニティと戻り先が表示される" do
        get edit_business_community_path(community)

        section = doc.at_css("#project-management")
        expect(section.at_css("h3").text).to eq "プロジェクト管理"
        expect(section.at_css(%(a[href="#{new_business_project_path(community_id: community.id)}"])).text).to eq "新しいプロジェクトを作成"

        get new_business_project_path(community_id: community.id)
        expect(response).to have_http_status(:ok)
        expect(doc.at_css(".project-new-community strong").text).to eq community.name
        expect(doc.at_css(%(.manage-page__breadcrumb a[href="#{business_community_project_management_path(community)}"]))).to be_present
        expect(doc.at_css(%(.form-actions a[href="#{business_community_project_management_path(community)}"])).text).to include("キャンセル")

        expect { create_project(community) }.to change(community.projects, :count).by(1)
        expect(response).to redirect_to(business_community_path(community))
        expect(flash[:notice]).to eq "プロジェクトを作成しました"
      end

      it "プロジェクト管理画面に作成ボタンと、プロジェクトごとの管理導線を出す" do
        get business_community_project_management_path(community)

        expect(response).to have_http_status(:ok)
        expect(current_tab).to eq "プロジェクト管理"
        expect(new_project_link.text).to eq "新しいプロジェクトを作成"
        expect(doc.at_css(%(.project-management__actions a[href="#{edit_business_project_path(project)}"]))).to be_present
      end
    end

    context "運営者ではないが、プロジェクトを作成できる参加者(お試し ON)" do
      before do
        community.update!(plan_restrictions_waived: true)
        sign_in free_member
      end

      it "編集画面は開けないが、通常画面の管理メニューからプロジェクト管理へ進み、作成できる" do
        get business_community_path(community)
        expect(new_project_link).to be_nil
        expect(manage_bar.css("a, [aria-current]").map { |el| el.text.strip }).to eq %w[通常画面 プロジェクト管理]

        get edit_business_community_path(community)
        expect(response).to redirect_to(business_community_path(community))

        get business_community_project_management_path(community)
        expect(response).to have_http_status(:ok)
        expect(new_project_link).to be_present
        # 自分が作成していないプロジェクトの編集・メンバー管理の導線は出さない。
        expect(doc.at_css(%(a[href="#{edit_business_project_path(project)}"]))).to be_nil

        expect { create_project(community) }.to change(community.projects, :count).by(1)
      end
    end

    [
      ["作成できない参加者(Free)", :free_member],
      ["非参加者", :outsider]
    ].each do |label, role|
      context label do
        before { sign_in public_send(role) }

        it "管理メニュー・作成導線が出ず、URL やリクエストを直接送っても作成できない" do
          get business_community_path(community)
          expect(manage_bar).to be_nil
          expect(new_project_link).to be_nil

          get business_community_project_management_path(community)
          expect(response).to redirect_to(business_community_path(community))
          expect(flash[:alert]).to eq "このコミュニティでプロジェクトを作成する権限がありません。"

          get new_business_project_path(community_id: community.id)
          expect(response).to redirect_to(business_community_path(community))

          expect { create_project(community) }.not_to change(Project, :count)
        end
      end
    end

    it "作成できるコミュニティの画面から、所属コミュニティ ID を作成できないコミュニティに書き換えても作成できない" do
      other_community = create(:community, owner: create(:customer), domain: business_domain)
      community.update!(plan_restrictions_waived: true)
      sign_in free_member

      expect {
        post business_projects_path, params: { project: { title: "書き換え", community_id: other_community.id } }
      }.not_to change(Project, :count)
      expect(response).to redirect_to(business_community_path(other_community))

      expect {
        post business_projects_path, params: { community_id: other_community.id, project: { title: "書き換え", community_id: community.id } }
      }.not_to change(Project, :count)
    end

    it "参加者向けのプロジェクト一覧(コミュニティ指定)にも作成ボタンを出さない" do
      sign_in owner

      get business_projects_path(community_id: community.id)

      expect(response).to have_http_status(:ok)
      expect(new_project_link).to be_nil
      expect(manage_bar.at_css(%(a[href="#{business_community_project_management_path(community)}"]))).to be_present
    end
  end

  describe "Business コミュニティの編集画面" do
    let(:business_domain) { Domain.find_or_create_by!(name: "business") }
    let(:owner) { create(:customer, domain_name: "business") }
    let(:community) { create(:community, owner: owner, domain: business_domain, name: "元の名前", introduction: "元の紹介") }

    before do
      CommunityCustomer.create!(community: community, customer: owner)
      sign_in owner
    end

    it "保存・キャンセル・通常画面・メンバー管理への導線があり、Danger Zone を出さない(削除の UI はもともと無い)" do
      get edit_business_community_path(community)

      expect(response).to have_http_status(:ok)
      expect(current_tab).to eq "編集"
      expect(doc.at_css(%(form[action="#{business_community_path(community)}"] input[type="submit"][value="保存する"]))).to be_present
      expect(doc.at_css(%(.form-actions a[href="#{business_community_path(community)}"])).text).to eq "キャンセル"
      expect(manage_bar.at_css(%(a[href="#{business_community_path(community)}"]))).to be_present
      expect(manage_bar.at_css(%(a[href="#{business_permits_path(community)}"]))).to be_present
      expect(doc.css("h2").map(&:text).count("コミュニティ編集")).to eq 1
    end

    it "保存に成功すると通常画面へ戻り、成功メッセージを出す" do
      patch business_community_path(community), params: { community: { name: "新しい名前" } }

      expect(response).to redirect_to(business_community_path(community))
      follow_redirect!
      expect(response.body).to include("更新しました")
      expect(community.reload.name).to eq "新しい名前"
    end

    it "入力エラーでは編集画面のまま、入力内容とエラーを保持して保存しない" do
      patch business_community_path(community), params: { community: { name: "", introduction: "書きかけの紹介" } }

      expect(response).to have_http_status(:ok)
      expect(doc.at_css(".alert-danger")).to be_present
      expect(doc.at_css("textarea[name='community[introduction]']").text.strip).to eq "書きかけの紹介"
      expect(doc.at_css(".manage-page__breadcrumb a").text).to eq "元の名前"
      expect(community.reload.name).to eq "元の名前"
      expect(community.introduction).to eq "元の紹介"
    end

    it "許可していない項目(オーナー・ドメイン)は更新できない" do
      other_owner = create(:customer)

      patch business_community_path(community), params: { community: { name: "変更", owner_id: other_owner.id, domain_id: Domain.find_or_create_by!(name: "music").id } }

      community.reload
      expect(community.owner_id).to eq owner.id
      expect(community.domain_id).to eq business_domain.id
    end
  end

  describe "音楽コミュニティ" do
    let(:owner) { create(:customer) }
    let(:member) { create(:customer) }
    let(:applicant) { create(:customer, name: "申請三郎") }
    let(:outsider) { create(:customer) }
    let!(:community) { create(:community, owner: owner, name: "元のバンド", introduction: "元の紹介") }

    before do
      CommunityCustomer.create!(community: community, customer: owner)
      CommunityCustomer.create!(community: community, customer: member)
      create(:permit, community_id: community.id, customer_id: applicant.id)
    end

    context "オーナー" do
      before { sign_in owner }

      it "通常画面に Danger Zone・編集フォームを出さず、管理メニューに編集・メンバー管理(承認待ち件数)を出す" do
        get public_community_path(community)

        expect(response).to have_http_status(:ok)
        expect(current_tab).to eq "通常画面"
        expect(manage_bar.at_css(%(a[href="#{edit_public_community_path(community)}"])).text.strip).to eq "編集"
        expect(manage_bar.at_css(%(a[href="#{public_permits_path(community)}"]) + " .manage-bar__badge").text).to eq "1"
        expect(doc.at_css(".danger-zone")).to be_nil
        expect(doc.at_css(%(a[data-method="delete"][href="#{public_community_path(community)}"]))).to be_nil
        expect(doc.at_css(%(form[action="#{public_community_path(community)}"][method="post"]))).to be_nil
        # 参加者向けの導線(イベント・ランキング)は残す。
        expect(doc.at_css(%(a[href="#{public_performance_rankings_path(scope: "community", community_id: community.id)}"]))).to be_present
      end

      it "編集画面の下部に Danger Zone を置き、保存・キャンセルの導線を出す" do
        get edit_public_community_path(community)

        expect(response).to have_http_status(:ok)
        expect(current_tab).to eq "編集"
        form = doc.at_css(%(form[action="#{public_community_path(community)}"]))
        expect(form.at_css(%(input[type="submit"][value="保存する"]))).to be_present
        expect(form.at_css(%(a[href="#{public_community_path(community)}"])).text).to eq "キャンセル"
        expect(form.at_css(".danger-zone")).to be_nil
        expect(doc.at_css(%(.danger-zone a[data-method="delete"][href="#{public_community_path(community)}"]))).to be_present
        expect(doc.at_css(".danger-zone .danger-confirm-input")).to be_present
      end

      it "保存に成功すると通常画面へ戻り、成功メッセージを出す" do
        patch public_community_path(community), params: { community: { name: "新しいバンド" } }

        expect(response).to redirect_to(public_community_path(community))
        expect(flash[:notice]).to eq "コミュニティの編集が完了しました!"
        expect(community.reload.name).to eq "新しいバンド"
      end

      it "入力エラーでは編集画面のまま、入力内容とエラーを保持して保存しない" do
        patch public_community_path(community), params: { community: { name: "", introduction: "書きかけ" } }

        expect(response).to have_http_status(:ok)
        expect(doc.at_css(".community-edit-title .alert li")).to be_present
        expect(doc.at_css("textarea[name='community[introduction]']").text.strip).to eq "書きかけ"
        expect(community.reload.name).to eq "元のバンド"
      end

      it "メンバー管理画面から通常画面・編集画面へ戻れる" do
        get public_permits_path(community)

        expect(response).to have_http_status(:ok)
        expect(current_tab).to eq "メンバー管理"
        expect(manage_bar.at_css(%(a[href="#{public_community_path(community)}"]))).to be_present
        expect(manage_bar.at_css(%(a[href="#{edit_public_community_path(community)}"]))).to be_present
        expect(response.body).to include("申請三郎")
      end
    end

    [
      ["一般参加者", :member],
      ["承認待ちの申請者", :applicant],
      ["非参加者", :outsider]
    ].each do |label, role|
      context label do
        before { sign_in public_send(role) }

        it "通常画面に管理メニューを出さない" do
          get public_community_path(community)

          expect(response).to have_http_status(:ok)
          expect(manage_bar).to be_nil
          expect(doc.at_css(%(a[href="#{edit_public_community_path(community)}"]))).to be_nil
          # 申請・申請取消(data-method 付き)は同じ URL なので、画面を開くリンクだけを見る。
          expect(doc.at_css(%(a[href="#{public_permits_path(community)}"]:not([data-method])))).to be_nil
        end

        it "編集・メンバー管理を URL で直接開けず、更新・削除もできない" do
          get edit_public_community_path(community)
          expect(response).to redirect_to(public_communities_path)

          get public_permits_path(community)
          expect(response).to redirect_to(public_communities_path)

          patch public_community_path(community), params: { community: { name: "乗っ取り" } }
          expect(community.reload.name).to eq "元のバンド"

          expect { delete public_community_path(community) }.not_to change(Community, :count)
        end
      end
    end

    it "一般参加者には退会、申請者には申請取消の操作を残す" do
      sign_in member
      get public_community_path(community)
      expect(doc.at_css(%(a[data-method="delete"][href="#{public_community_leave_path(community)}"]))).to be_present

      sign_in applicant
      get public_community_path(community)
      expect(doc.at_css(%(a[data-method="delete"][href="#{public_community_permits_path(community)}"]))).to be_present
    end
  end
end
