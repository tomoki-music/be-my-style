require "rails_helper"

# プロジェクト削除: ボタン・確認画面・削除処理が同じ権限(管理者と親コミュニティのオーナー本人)で判定されること。
RSpec.describe "Business プロジェクトの削除", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:admin_customer) { create(:customer, domain_name: "business", onboarding_done: true, is_owner: :admin) }
  let(:creator) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:co_owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:member) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:other_owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "親コミュニティ") }
  let!(:other_community) { create(:community, owner: other_owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: creator, title: "削除対象プロジェクト") }
  let!(:other_project) { Project.create!(community: community, customer: owner, title: "残るプロジェクト") }
  let(:thread) { ProjectThread.create!(project: project, customer: creator, title: "打ち合わせ") }
  let!(:chat) { ProjectChat.create!(project: project, project_thread: thread, customer: creator, body: "資料を共有します") }

  before do
    [owner, creator, co_owner, member].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    CommunityCustomer.create!(community: other_community, customer: other_owner)
    CommunityOwner.create!(community: community, customer: co_owner)
    ProjectMember.create!(project: project, customer: member)
    ProjectJoinRequest.create!(project: project, customer: other_owner)
  end

  def delete_button_shown?
    Nokogiri::HTML(response.body).at_css("#project-delete a[href='#{destroy_confirmation_business_project_path(project)}']").present?
  end

  [["管理者", :admin_customer], ["親コミュニティのオーナー", :owner]].each do |label, actor|
    context label do
      before { sign_in public_send(actor) }

      it "編集画面の下部に削除ボタンが出る" do
        get edit_business_project_path(project)

        expect(response).to have_http_status(:ok)
        expect(delete_button_shown?).to eq true
      end

      it "確認画面にプロジェクト名・削除される件数・キャンセルの戻り先が出て、開いただけでは何も消えない" do
        expect { get destroy_confirmation_business_project_path(project) }.not_to change(Project, :count)

        expect(response).to have_http_status(:ok)
        doc = Nokogiri::HTML(response.body)
        expect(doc.text).to include("「削除対象プロジェクト」を削除しますか？")
        items = doc.css(".ba-danger-zone__list li").map { |li| li.text.squish }
        expect(items).to eq [
          "スレッド #{project.project_threads.count}件",
          "スレッド内の投稿 1件",
          "参加メンバーの登録(会員アカウントは残ります) 1件",
          "承認待ちの参加申請 1件"
        ]
        expect(doc.at_css("a.ba-btn--secondary[href='#{edit_business_project_path(project)}']").text).to eq "キャンセル"
        expect(doc.at_css("form[action='#{business_project_path(project)}'] input[name='_method'][value='delete']")).to be_present
      end

      it "削除すると関連データも消え、親コミュニティへ完了メッセージ付きで戻る(コミュニティ・他のプロジェクト・会員は残る)" do
        project_id = project.id

        expect { delete business_project_path(project) }.to change(Project, :count).by(-1)

        expect(response).to redirect_to(business_community_path(community))
        expect(flash[:notice]).to eq "プロジェクト「削除対象プロジェクト」を削除しました。"
        expect(ProjectThread.where(project_id: project_id)).to be_empty
        expect(ProjectChat.where(project_id: project_id)).to be_empty
        expect(ProjectMember.where(project_id: project_id)).to be_empty
        expect(ProjectJoinRequest.where(project_id: project_id)).to be_empty
        expect(Community.exists?(community.id)).to eq true
        expect(Project.exists?(other_project.id)).to eq true
        expect(Customer.where(id: [creator.id, member.id]).count).to eq 2

        follow_redirect!
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("プロジェクト「削除対象プロジェクト」を削除しました。")
        expect(response.body).to include("残るプロジェクト")
      end
    end
  end

  [
    ["作成者のみ", :creator],
    ["編集権限のみの運営者(CommunityOwner)", :co_owner],
    ["一般メンバー", :member],
    ["別コミュニティのオーナー", :other_owner]
  ].each do |label, actor|
    context label do
      before { sign_in public_send(actor) }

      it "編集画面に削除ボタンが出ない(開ける場合)" do
        get edit_business_project_path(project)

        expect(delete_button_shown?).to eq false
        expect(response.body).not_to include("プロジェクトを削除")
      end

      it "確認画面を直接開いても戻され、削除リクエストを直接送っても消えない" do
        get destroy_confirmation_business_project_path(project)
        expect(response).to redirect_to(business_project_path(project))
        expect(flash[:alert]).to eq "このプロジェクトを削除する権限がありません。"

        expect { delete business_project_path(project) }.not_to change(Project, :count)
        expect(response).to redirect_to(business_project_path(project))
        expect(ProjectChat.exists?(chat.id)).to eq true
      end
    end
  end

  it "作成者と運営者は編集できる(編集権限があっても削除はできない前提の確認)" do
    expect(creator.business_project_manager?(project)).to eq true
    expect(co_owner.business_project_manager?(project)).to eq true
    expect(creator.can_destroy_business_project?(project)).to eq false
    expect(co_owner.can_destroy_business_project?(project)).to eq false
    expect(other_owner.can_destroy_business_project?(project)).to eq false
    expect(owner.can_destroy_business_project?(project)).to eq true
    expect(admin_customer.can_destroy_business_project?(project)).to eq true
  end

  it "音楽側コミュニティのプロジェクトは Business 画面から削除できない" do
    music_community = create(:community, owner: owner)
    music_project = Project.create!(community: music_community, customer: owner, title: "音楽側")
    sign_in owner

    expect { delete business_project_path(music_project) }.to raise_error(ActiveRecord::RecordNotFound)
    expect(Project.exists?(music_project.id)).to eq true
  end
end
