require "rails_helper"

# コミュニティ削除: ボタン・確認画面の表示と削除処理が同じ権限(オーナー本人と管理者)で判定されること。
RSpec.describe "Business コミュニティの削除", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:admin_customer) { create(:customer, domain_name: "business", onboarding_done: true, is_owner: :admin) }
  let(:co_owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:member) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:outsider) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "削除対象ラボ") }
  let(:project) { Project.create!(community: community, customer: owner, title: "削除対象プロジェクト") }
  let(:thread) { ProjectThread.create!(project: project, customer: owner, title: "打ち合わせ") }

  before do
    [owner, co_owner, member].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    CommunityOwner.create!(community: community, customer: co_owner)
    ProjectChat.create!(project: project, project_thread: thread, customer: owner, body: "資料を共有します")
    CommunityPost.create!(community: community, customer: member, body: "タイムラインの投稿")
  end

  def delete_button_shown?
    Nokogiri::HTML(response.body).at_css("#community-delete a[href='#{destroy_confirmation_business_community_path(community)}']").present?
  end

  [["オーナー", :owner], ["管理者", :admin_customer]].each do |label, actor|
    context label do
      before { sign_in public_send(actor) }

      it "編集画面の下部に削除ボタンが出る" do
        get edit_business_community_path(community)

        expect(response).to have_http_status(:ok)
        expect(delete_button_shown?).to eq true
      end

      it "確認画面に対象名・削除される件数・キャンセルの戻り先が出て、開いただけでは何も消えない" do
        expect { get destroy_confirmation_business_community_path(community) }.not_to change(Community, :count)

        expect(response).to have_http_status(:ok)
        doc = Nokogiri::HTML(response.body)
        expect(doc.text).to include("「削除対象ラボ」を削除しますか？")
        items = doc.css(".ba-danger-zone__list li").map { |li| li.text.squish }
        expect(items).to include("プロジェクト 1件", "プロジェクトのスレッド 2件", "プロジェクト内の投稿 1件",
                                 "タイムラインの投稿 1件", "参加メンバーの登録(会員アカウントは残ります) 3件", "承認待ちの参加申請 0件")
        expect(doc.at_css("a.ba-btn--secondary[href='#{edit_business_community_path(community)}']").text).to eq "キャンセル"
        expect(doc.at_css("form[action='#{business_community_path(community)}'] input[name='_method'][value='delete']")).to be_present
      end

      it "削除するとプロジェクト・投稿も消え、コミュニティ一覧へ完了メッセージ付きで戻る(会員は残る)" do
        project_id = project.id

        expect { delete business_community_path(community) }.to change(Community, :count).by(-1)

        expect(response).to redirect_to(business_communities_path)
        expect(flash[:notice]).to eq "コミュニティ「削除対象ラボ」を削除しました。"
        expect(Project.exists?(project_id)).to eq false
        expect(ProjectThread.where(project_id: project_id)).to be_empty
        expect(ProjectChat.where(project_id: project_id)).to be_empty
        expect(CommunityPost.where(community_id: community.id)).to be_empty
        expect(Customer.where(id: [owner.id, co_owner.id, member.id]).count).to eq 3

        follow_redirect!
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("コミュニティ「削除対象ラボ」を削除しました。")
      end
    end
  end

  [["編集権限のみの運営者(CommunityOwner)", :co_owner], ["一般メンバー", :member], ["非参加者", :outsider]].each do |label, actor|
    context label do
      before { sign_in public_send(actor) }

      it "編集画面に削除ボタンが出ない(開ける場合)" do
        get edit_business_community_path(community)

        expect(delete_button_shown?).to eq false
        expect(response.body).not_to include("コミュニティを削除")
      end

      it "確認画面を直接開いても戻され、削除リクエストを直接送っても消えない" do
        get destroy_confirmation_business_community_path(community)
        expect(response).to redirect_to(business_community_path(community))
        expect(flash[:alert]).to eq "このコミュニティを削除する権限がありません。"

        expect { delete business_community_path(community) }.not_to change(Community, :count)
        expect(response).to redirect_to(business_community_path(community))
        expect(Project.exists?(project.id)).to eq true
      end
    end
  end

  it "共催イベントの主催で削除できないときは、確認画面ではなく既存の案内画面へ進める" do
    other = create(:community, owner: owner, domain: business_domain)
    event = create(:event, :event_with_songs, community: community)
    event.update!(selected_cohost_community_ids: [other.id])
    sign_in owner

    get destroy_confirmation_business_community_path(community)

    expect(response).to redirect_to(destroy_blocked_business_community_path(community))
  end

  it "Customer#can_destroy_community? は管理権限(CommunityOwner)だけでは許可しない" do
    expect(owner.can_destroy_community?(community)).to eq true
    expect(admin_customer.can_destroy_community?(community)).to eq true
    expect(co_owner.can_manage_community?(community)).to eq true
    expect(co_owner.can_destroy_community?(community)).to eq false
    expect(member.can_destroy_community?(community)).to eq false
  end
end
