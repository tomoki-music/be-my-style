require "rails_helper"

# 一般の Business 利用者が コミュニティ一覧 → 詳細で参加 → プロジェクト詳細で参加 → スレッド利用 と進めること。
# 状態(未参加・承認待ち・参加中・停止中・運営・管理権限あり)ごとの表示と、直接リクエストでの認可を確かめる。
RSpec.describe "Business のコミュニティ・プロジェクト参加導線", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }

  let(:owner) { create(:customer, name: "運営 さくら", domain_name: "business", onboarding_done: true) }
  let(:general) { create(:customer, name: "一般 たろう", domain_name: "business", onboarding_done: true) }
  let(:admin) { create(:customer, name: "管理 はなこ", domain_name: "business", onboarding_done: true, is_owner: :admin) }

  let!(:manual_community) do
    Community.create!(name: "デザイン勉強会", introduction: "UIデザインを学び合います。", owner: owner, domain: business_domain,
                      required_plan_for_event_creation: "premium", join_approval_mode: :manual)
  end
  let!(:auto_community) do
    Community.create!(name: "スタートアップ交流会", introduction: "起業準備中の人の集まり。", owner: owner, domain: business_domain,
                      required_plan_for_event_creation: "premium", join_approval_mode: :auto)
  end
  let!(:manual_project) do
    Project.create!(community: manual_community, customer: owner, title: "ポートフォリオ相互レビュー", description: "作品を見せ合う", join_approval_mode: :manual)
  end
  let!(:auto_project) do
    Project.create!(community: auto_community, customer: owner, title: "ピッチ練習会", description: "1分ピッチを練習", join_approval_mode: :auto)
  end

  before do
    CommunityCustomer.create!(community: manual_community, customer: owner)
    CommunityCustomer.create!(community: auto_community, customer: owner)
    CommunityPost.create!(community: manual_community, customer: owner, body: "内部のお知らせ")
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def tile_for(name)
    doc.css(".ba-community-tile").find { |tile| tile.at_css(".ba-community-tile__name").text == name }
  end

  def join_panel
    doc.at_css("#community-join, #project-join")
  end

  describe "コミュニティ一覧" do
    it "各カードが詳細へのリンクで、参加状況(未参加は参加方式)と「詳細」の導線を出す" do
      Permit.create!(community: manual_community, customer: general)
      sign_in general

      get business_communities_path

      manual = tile_for("デザイン勉強会")
      auto = tile_for("スタートアップ交流会")
      expect(manual["href"]).to eq business_community_path(manual_community)
      expect(manual.at_css(".ba-status").text.strip).to eq "承認待ち"
      expect(manual.at_css(".ba-community-tile__cta").text.strip).to eq "詳細を見る"
      expect(auto.at_css(".ba-status").text.strip).to eq "自動承認"
      expect(auto.at_css(".ba-community-tile__cta").text.strip).to eq "詳細・参加方法を見る"
      expect(auto.at_css(".ba-community-tile__meta").text).to include("1人")
    end
  end

  describe "コミュニティ詳細の参加表示" do
    it "未参加(手動承認)は紹介の近くに「参加を申請する」を出し、内部の会話・メンバーは出さない" do
      sign_in general
      get business_community_path(manual_community)

      button = join_panel.at_css(%(a[data-method="post"][href="#{business_community_permit_path(manual_community)}"]))
      expect(button.text.strip).to eq "参加を申請する"
      expect(button["data-disable-with"]).to be_present
      expect(doc.at_css(".ba-profile #community-join")).to be_present
      expect(response.body).not_to include("内部のお知らせ")
      expect(doc.at_css("#members")).to be_nil
      expect(doc.at_css("#projects")).to be_nil
    end

    it "未参加(自動承認)は「参加する」を出す" do
      sign_in general
      get business_community_path(auto_community)

      expect(join_panel.at_css("a.ba-btn--primary").text.strip).to eq "参加する"
    end

    it "承認待ちは「承認待ち」と「申請を取り消す」を出し、参加ボタンは出さない" do
      Permit.create!(community: manual_community, customer: general)
      sign_in general
      get business_community_path(manual_community)

      expect(join_panel.at_css(".ba-status").text.strip).to eq "承認待ち"
      expect(join_panel.at_css(%(a[data-method="delete"])).text.strip).to eq "申請を取り消す"
      expect(join_panel.at_css(%(a[data-method="post"]))).to be_nil
    end

    it "参加中は「参加中」・プロジェクトへの導線・退出の導線を出す" do
      CommunityCustomer.create!(community: manual_community, customer: general)
      sign_in general
      get business_community_path(manual_community)

      expect(join_panel.at_css(".ba-status").text.strip).to eq "参加中"
      expect(join_panel.at_css(%(a[href="#projects"])).text.strip).to eq "プロジェクトを見る"
      expect(doc.at_css(%(#members a[data-method="delete"][href="#{business_community_community_customers_path(manual_community)}"])).text.strip).to eq "コミュニティから退出する"
      expect(response.body).to include("内部のお知らせ")
    end

    it "停止中は参加ボタンを出さず、再参加できない理由を出す" do
      CommunityAccessSuspension.create!(community: manual_community, customer: general)
      sign_in general
      get business_community_path(manual_community)

      expect(join_panel.at_css(".ba-status").text.strip).to eq "アクセス停止中"
      expect(join_panel.text).to include("再参加・再申請はできません")
      expect(join_panel.at_css("a")).to be_nil
    end

    it "運営者は「運営」、システム管理者は「管理権限あり」と出し、参加申請が不要な理由を添える" do
      sign_in owner
      get business_community_path(manual_community)
      expect(join_panel.at_css(".ba-status").text.strip).to eq "運営"
      expect(join_panel.text).to include("参加申請は不要です")
      expect(doc.at_css("#members a[data-method='delete']")).to be_nil

      sign_in admin
      get business_community_path(manual_community)
      expect(join_panel.at_css(".ba-status").text.strip).to eq "管理権限あり"
      expect(join_panel.at_css("a")).to be_nil
    end
  end

  describe "プロジェクト詳細の参加表示" do
    before { CommunityCustomer.create!(community: manual_community, customer: general) }

    it "親コミュニティ未参加なら概要も見せず、コミュニティの参加案内へ戻す" do
      sign_in general
      get business_project_path(auto_project)

      expect(response).to redirect_to(business_community_path(auto_community))
      expect(flash[:alert]).to eq "このプロジェクトに参加するには、先にコミュニティへの参加が必要です。"
    end

    it "未参加(手動承認)は「参加を申請する」、承認待ちは「申請を取り消す」、参加中は「参加中」とスレッドへの導線" do
      sign_in general

      get business_project_path(manual_project)
      expect(join_panel.at_css(%(a[data-method="post"][href="#{join_business_project_path(manual_project)}"])).text.strip).to eq "参加を申請する"
      expect(doc.at_css("#threads")).to be_nil

      ProjectJoinRequest.create!(project: manual_project, customer: general)
      get business_project_path(manual_project)
      expect(join_panel.at_css(".ba-status").text.strip).to eq "承認待ち"
      expect(join_panel.at_css(%(a[data-method="delete"])).text.strip).to eq "申請を取り消す"

      ProjectJoinRequest.where(project: manual_project, customer: general).delete_all
      ProjectMember.create!(project: manual_project, customer: general)
      get business_project_path(manual_project)
      expect(join_panel.at_css(".ba-status").text.strip).to eq "参加中"
      expect(join_panel.at_css(%(a[href="#threads"]))).to be_present
      expect(doc.at_css("#threads")).to be_present
      expect(doc.at_css(%(a[href="#{leave_business_project_path(manual_project)}"]))).to be_present
    end

    it "停止中は参加ボタンを出さない。取りやめた締切が過去日でも参加ボタンを出す" do
      ProjectAccessSuspension.create!(project: manual_project, customer: general)
      sign_in general
      get business_project_path(manual_project)
      expect(join_panel.at_css(".ba-status").text.strip).to eq "アクセス停止中"
      expect(join_panel.at_css("a")).to be_nil

      manual_project.update_columns(deadline: 1.day.ago)
      ProjectAccessSuspension.delete_all
      get business_project_path(manual_project)
      expect(join_panel.at_css("a").text.strip).to eq "参加を申請する"
      expect(response.body).not_to include("募集終了")
      expect(response.body).not_to include("締切")
    end

    it "運営者・作成者・システム管理者には参加ボタンの代わりに権限を出す" do
      sign_in owner
      get business_project_path(manual_project)
      expect(join_panel.at_css(".ba-status").text.strip).to eq "運営"

      creator_project = Project.create!(community: manual_community, customer: general, title: "自分の企画", description: "説明")
      sign_in general
      get business_project_path(creator_project)
      expect(join_panel.at_css(".ba-status").text.strip).to eq "主催"

      sign_in admin
      get business_project_path(manual_project)
      expect(join_panel.at_css(".ba-status").text.strip).to eq "管理権限あり"
    end

    it "プロジェクト一覧とコミュニティ詳細のカードにも参加状況を出す" do
      sign_in general

      get business_projects_path
      card = doc.css(".ba-project-card").find { |c| c.at_css(".ba-project-card__title").text == "ポートフォリオ相互レビュー" }
      expect(card.at_css(".ba-status").text.strip).to eq "承認制"
      expect(response.body).not_to include("ピッチ練習会")

      get business_community_path(manual_community)
      expect(doc.at_css("#projects .ba-project-card .ba-status").text.strip).to eq "承認制"
    end
  end

  describe "一般利用者の一連の操作" do
    it "自動承認コミュニティに参加 → 自動承認プロジェクトに参加 → スレッドへ投稿できる" do
      sign_in general

      post business_community_permit_path(auto_community)
      expect(response).to redirect_to(business_community_path(auto_community))
      expect(flash[:notice]).to eq "コミュニティに参加しました"

      post join_business_project_path(auto_project)
      expect(flash[:notice]).to eq "プロジェクトに参加しました！"

      thread = ProjectThread.general_for!(auto_project)
      expect {
        post business_project_thread_project_chats_path(auto_project, thread), params: { project_chat: { body: "よろしくお願いします" } }
      }.to change(ProjectChat, :count).by(1)
    end

    it "手動承認は承認されるまでプロジェクトへ進めず、承認後に申請・承認を経てスレッドを見られる" do
      sign_in general
      post business_community_permit_path(manual_community)
      expect(flash[:notice]).to eq "コミュニティへ参加申請しました"

      get business_project_path(manual_project)
      expect(response).to redirect_to(business_community_path(manual_community))

      sign_in owner
      post business_community_community_customers_path(manual_community, customer_id: general.id)

      sign_in general
      post join_business_project_path(manual_project)
      expect(flash[:notice]).to eq "プロジェクトへ参加申請しました"

      sign_in owner
      post approve_business_project_join_request_path(manual_project, ProjectJoinRequest.find_by!(project: manual_project, customer: general))

      sign_in general
      get business_project_path(manual_project)
      expect(doc.at_css("#threads")).to be_present
    end
  end

  describe "コミュニティからの退出" do
    let(:leave_path) { business_community_community_customers_path(manual_community) }

    before do
      CommunityCustomer.create!(community: manual_community, customer: general)
      ProjectMember.create!(project: manual_project, customer: general)
      sign_in general
    end

    it "GET では退出しない(変更は DELETE だけ)" do
      expect { get leave_path }.to raise_error(ActionController::RoutingError)
      expect(general.business_community_member?(manual_community)).to eq true
    end

    it "CSRF トークンの無い DELETE は受け付けない" do
      ActionController::Base.allow_forgery_protection = true
      expect { delete leave_path }.to raise_error(ActionController::InvalidAuthenticityToken)
      expect(general.business_community_member?(manual_community)).to eq true
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "画面のリンクは CSRF トークン付きの DELETE として送られる(rails-ujs がメタタグのトークンを付ける)" do
      ActionController::Base.allow_forgery_protection = true
      get business_community_path(manual_community)

      link = doc.at_css(%(a[href="#{leave_path}"]))
      expect(link["data-method"]).to eq "delete"
      expect(link["data-confirm"]).to be_present
      expect(doc.at_css('meta[name="csrf-token"]')["content"]).to be_present
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "退出後は内部コンテンツを見られず、配下プロジェクトも親コミュニティの参加資格が必要になる" do
      delete leave_path

      expect(general.business_community_member?(manual_community)).to eq false
      expect(ProjectMember.where(project: manual_project, customer: general)).to be_empty

      get business_community_path(manual_community)
      expect(response.body).not_to include("内部のお知らせ")
      expect(join_panel.at_css("a.ba-btn--primary").text.strip).to eq "参加を申請する"

      get business_project_path(manual_project)
      expect(response).to redirect_to(business_community_path(manual_community))

      expect { post join_business_project_path(manual_project) }.not_to change(ProjectJoinRequest, :count)
      expect(flash[:alert]).to eq "プロジェクトに参加するには、先にコミュニティへ参加してください"
    end

    it "運営者には退出リンクを出さず、運営者として引き続き閲覧できる(既存仕様)" do
      sign_in owner
      get business_community_path(manual_community)

      expect(doc.at_css(%(a[href="#{leave_path}"]))).to be_nil
      expect(response.body).to include("内部のお知らせ")
    end
  end

  describe "直接リクエストでの認可と重複防止" do
    it "連打しても参加・申請は1件だけ" do
      sign_in general

      3.times { post business_community_permit_path(manual_community) }
      3.times { post business_community_permit_path(auto_community) }

      expect(Permit.where(community: manual_community, customer: general).count).to eq 1
      expect(CommunityCustomer.where(community: auto_community, customer: general).count).to eq 1

      3.times { post join_business_project_path(auto_project) }
      expect(ProjectMember.where(project: auto_project, customer: general).count).to eq 1
    end

    it "停止中はボタンを経由しない直接リクエストでも参加・申請できない" do
      CommunityAccessSuspension.create!(community: auto_community, customer: general)
      sign_in general

      expect { post business_community_permit_path(auto_community) }.not_to change(CommunityCustomer, :count)
      expect(flash[:alert]).to eq "このコミュニティへのアクセスは停止されています"
    end

    it "親コミュニティ未参加のプロジェクトへは直接リクエストでも参加できない" do
      sign_in general

      expect { post join_business_project_path(auto_project) }.not_to change(ProjectMember, :count)
      expect(response).to redirect_to(business_community_path(auto_community))
    end

    it "申請の取り消しは本人の申請だけを消す" do
      other = create(:customer, domain_name: "business", onboarding_done: true)
      Permit.create!(community: manual_community, customer: other)
      Permit.create!(community: manual_community, customer: general)
      sign_in general

      delete business_community_permit_path(manual_community)

      expect(Permit.where(community: manual_community).pluck(:customer_id)).to eq [other.id]
    end
  end
end
