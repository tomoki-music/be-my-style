require "rails_helper"

# プライベート(招待制)プロジェクト。
#   - 一覧・検索・通知に出さない。詳細・スレッド・投稿・メンバー・添付は参加者と管理者だけ(それ以外は存在も分からない 404)。
#   - 参加は招待リンクからだけ(親コミュニティへの所属は求めない)。参加・参加申請のボタン/POST は受け付けない。
#   - 招待リンクの発行・無効化、プライベートへの変更・プライベートからの変更は、システム管理者と親コミュニティのオーナー本人だけ。
RSpec.describe "Business プライベートプロジェクト", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:owner) { create(:customer, domain_name: "business", name: "オーナーさん", onboarding_done: true) }
  let(:co_manager) { create(:customer, domain_name: "business", name: "運営者さん", onboarding_done: true) }
  let(:admin) { create(:customer, domain_name: "business", name: "システム管理者", is_owner: :admin, onboarding_done: true) }
  let(:creator) { create(:customer, domain_name: "business", name: "作成者さん", onboarding_done: true) }
  let(:community_member) { create(:customer, domain_name: "business", name: "コミュニティ参加者さん", onboarding_done: true) }
  let(:invitee) { create(:customer, domain_name: "business", name: "招待された人", onboarding_done: true) }
  let(:community) do
    create(:community, owner: owner, domain: business_domain, name: "親コミュニティ", introduction: "紹介文", join_approval_mode: :manual)
  end
  let!(:secret) do
    Project.create!(community: community, customer: creator, title: "ひみつの企画", description: "内部の説明", visibility: :private)
  end
  let!(:listed) { Project.create!(community: community, customer: owner, title: "通常公開の企画", description: "誰でも探せます") }
  let!(:unlisted) do
    Project.create!(community: community, customer: owner, title: "限定公開の企画", description: "URLを知る人だけ", visibility: :unlisted)
  end

  before do
    [owner, co_manager, creator, community_member].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    CommunityOwner.create!(community: community, customer: co_manager)
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def issue_link(project = secret, by: owner, expiry_days: 7)
    ProjectInvitationLink.issue!(project: project, created_by: by, expiry_days: expiry_days)
  end

  def general_thread(project = secret)
    project.project_threads.find_by!(general: true)
  end

  def open_link(client, token)
    client.get business_project_invitation_path(token: token)
    expect(client.response).to have_http_status(:found)
    # トークンはアドレスバー・履歴に残さず、トークンの無い受け入れ画面へ移る。
    expect(client.response.location).not_to include(token)
    expect(URI.parse(client.response.location).path).to eq business_project_invitation_path
    client.follow_redirect!
  end

  def redirected_path(client)
    expect(client.response).to have_http_status(:found)
    URI.parse(client.response.location).path
  end

  describe "招待なしの閲覧・参加の拒否" do
    it "コミュニティ参加者・コミュニティ外の人には、詳細・スレッド・メンバー・投稿・参加を存在しない場合と同じ 404 にする" do
      thread = general_thread
      [community_member, invitee].each do |customer|
        sign_in customer
        expect { get business_project_path(secret) }.to raise_error(ActiveRecord::RecordNotFound)
        sign_in customer
        expect { get business_project_threads_path(secret) }.to raise_error(ActiveRecord::RecordNotFound)
        sign_in customer
        expect { get business_project_thread_path(secret, thread) }.to raise_error(ActiveRecord::RecordNotFound)
        sign_in customer
        expect { get members_business_project_path(secret) }.to raise_error(ActiveRecord::RecordNotFound)
        sign_in customer
        expect {
          post business_project_thread_project_chats_path(secret, thread), params: { project_chat: { body: "のぞき見" } }
        }.to raise_error(ActiveRecord::RecordNotFound)
        sign_in customer
        expect { post join_business_project_path(secret) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      expect(ProjectChat.where(project: secret)).to be_empty
      expect(secret.project_members).to be_empty
      expect(secret.project_join_requests).to be_empty
    end

    it "参加・参加申請の処理はプライベートを受け付けない(コミュニティ参加者でも)" do
      secret.update!(join_approval_mode: :auto)
      expect(Business::Memberships::JoinProject.call(project: secret, customer: community_member)).to eq :invite_only
      secret.update!(join_approval_mode: :manual)
      expect(Business::Memberships::JoinProject.call(project: secret, customer: community_member, message: "入れて")).to eq :invite_only
      expect(secret.project_members.count + secret.project_join_requests.count).to eq 0
    end

    it "添付ファイルは参加者以外には 404 にする" do
      ProjectMember.create!(project: secret, customer: invitee)
      chat = ProjectChat.create!(project: secret, customer: invitee, project_thread: general_thread, body: "資料です")
      chat.attachments.attach(io: File.open(Rails.root.join("spec/fixtures/files/business_chat/sample.pdf")), filename: "sample.pdf",
                              content_type: "application/pdf")
      attachment = chat.attachments.first

      sign_in community_member
      get business_chat_attachment_path(attachment)
      expect(response).to have_http_status(:not_found)

      sign_in invitee
      get business_chat_attachment_path(attachment)
      expect(response).to have_http_status(:found)
    end

    it "ホーム・プロジェクト一覧・コミュニティ詳細の一覧に出さない(参加者・オーナーにも)" do
      ProjectMember.create!(project: secret, customer: community_member)
      [community_member, owner].each do |customer|
        sign_in customer
        get business_root_path
        expect(response.body).not_to include("ひみつの企画")
        get business_projects_path
        expect(response.body).not_to include("ひみつの企画")
        get business_community_path(community)
        expect(response.body).to include("通常公開の企画")
        expect(response.body).not_to include("ひみつの企画")
      end
    end

    it "コミュニティの「プロジェクト管理」には、参加者・管理者に見えるときだけ「プライベート」のしるし付きで出す" do
      other_creator = create(:customer, domain_name: "business", onboarding_done: true)
      CommunityCustomer.create!(community: community, customer: other_creator)
      allow_any_instance_of(Customer).to receive(:can_create_project_for?).and_return(true)

      sign_in owner
      get business_community_project_management_path(community)
      row = doc.css(".ba-row").find { |node| node.text.include?("ひみつの企画") }
      expect(row.at_css(".ba-status--private").text.strip).to eq "プライベート"

      sign_in other_creator
      get business_community_project_management_path(community)
      expect(response.body).to include("通常公開の企画", "限定公開の企画")
      expect(response.body).not_to include("ひみつの企画")
    end

    it "管理権限のある人(作成者・運営者・オーナー・システム管理者)は招待なしで詳細を開ける" do
      [creator, co_manager, owner, admin].each do |customer|
        sign_in customer
        get business_project_path(secret)
        expect(response).to have_http_status(:ok)
        expect(doc.at_css("h1").text).to eq "ひみつの企画"
        expect(doc.at_css(".ba-status--private").text.strip).to eq "プライベート"
        # 詳細URLの招待用URLは出さない(このURLでは参加できない)。
        expect(doc.at_css("#share-project-#{secret.id}")).to be_nil
      end
    end
  end

  describe "通知・投稿の選択肢" do
    it "プライベートを作成しても、コミュニティ参加者へ作成通知を送らない" do
      allow_any_instance_of(Customer).to receive(:has_feature?).and_call_original
      allow_any_instance_of(Customer).to receive(:has_feature?).with(:business_project_create, community: community).and_return(true)
      sign_in owner
      expect {
        post business_projects_path, params: { project: { community_id: community.id, title: "新しいひみつ", description: "x", visibility: "private" } }
      }.not_to change { Notification.where(action: "project_created").count }
      expect(Project.find_by!(title: "新しいひみつ")).to be_visibility_private

      expect {
        post business_projects_path, params: { project: { community_id: community.id, title: "新しい公開", description: "x", visibility: "listed" } }
      }.to change { Notification.where(action: "project_created").count }
    end

    it "後からプライベートにしたプロジェクトの過去の通知は、参加者以外にはプロジェクト名を出さない" do
      community_member.business_notification_project_created(owner, listed)
      Business::Projects::ChangeVisibility.call(project: listed, visibility: "private")

      sign_in community_member
      get business_notifications_path
      expect(response.body).to include("閲覧できないプロジェクトの通知です")
      expect(response.body).not_to include("通常公開の企画")
      expect(doc.css("a.ba-notification")).to be_empty
    end

    it "ビジネス投稿(ログイン中の全員が見られる)のプロジェクトの選択肢にプライベートを出さない" do
      ProjectMember.create!(project: secret, customer: community_member)
      ProjectMember.create!(project: listed, customer: community_member)
      sign_in community_member
      get new_business_post_path
      options = doc.css("select#post_project_id option").map(&:text)
      expect(options).to include("通常公開の企画")
      expect(options).not_to include("ひみつの企画")
    end
  end

  describe "招待リンクの発行・無効化" do
    it "親コミュニティのオーナーは発行でき、リンクはその応答にだけ表示される(トークンは保存しない)" do
      sign_in owner
      get business_project_invitation_link_path(secret)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("招待リンクはまだ発行されていません")

      post business_project_invitation_link_path(secret), params: { expiry_days: "30" }
      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to include("no-store")
      url = doc.at_css("#invitation-link-url")["value"]
      token = Rack::Utils.parse_query(URI.parse(url).query).fetch("token")
      expect(token.length).to be >= 43

      link = secret.project_invitation_links.last!
      expect(link.token_digest).to eq ProjectInvitationLink.digest(token)
      expect(link.attributes.values.map(&:to_s)).not_to include(token)
      expect(link.expires_at).to be_within(1.minute).of(30.days.from_now)
      expect(link.created_by).to eq owner

      get business_project_invitation_link_path(secret)
      expect(response.body).not_to include(token)
      expect(doc.at_css(".ba-invite-link__facts").text).to include("有効", "0人")
    end

    it "選択肢にない期限は既定の7日にする" do
      sign_in owner
      post business_project_invitation_link_path(secret), params: { expiry_days: "365" }
      expect(secret.project_invitation_links.last!.expires_at).to be_within(1.minute).of(7.days.from_now)
    end

    it "再発行すると古いリンクは使えなくなり、無効化するとどのリンクも使えなくなる" do
      _old_link, old_token = issue_link
      sign_in owner
      post business_project_invitation_link_path(secret)
      new_token = Rack::Utils.parse_query(URI.parse(doc.at_css("#invitation-link-url")["value"]).query).fetch("token")
      expect(ProjectInvitationLink.find_by_token(old_token).status).to eq :revoked
      expect(ProjectInvitationLink.find_by_token(new_token).status).to eq :active

      delete business_project_invitation_link_path(secret)
      expect(response).to redirect_to(business_project_invitation_link_path(secret))
      expect(ProjectInvitationLink.find_by_token(new_token).status).to eq :revoked
    end

    it "システム管理者も発行できるが、運営者・プロジェクト作成者は発行・無効化できない" do
      sign_in admin
      post business_project_invitation_link_path(secret)
      expect(response).to have_http_status(:ok)

      [co_manager, creator].each do |customer|
        sign_in customer
        expect {
          post business_project_invitation_link_path(secret)
          delete business_project_invitation_link_path(secret)
        }.not_to(change { ProjectInvitationLink.order(:id).pluck(:id, :revoked_at) })
        expect(response).to redirect_to(business_project_path(secret))

        get business_project_path(secret)
        expect(doc.css(".ba-manage-bar a").map(&:text)).not_to include("招待リンク")
      end
    end

    it "プライベートでないプロジェクトでは発行できない" do
      sign_in owner
      post business_project_invitation_link_path(listed)
      expect(response).to redirect_to(edit_business_project_path(listed))
      expect(ProjectInvitationLink.count).to eq 0
    end

    it "トークンはログに出さない(リクエストのパスは :token を伏せた形で記録される)" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      expect(filter.filter("token" => "secret-token")).to eq("token" => "[FILTERED]")

      # Rails のリクエストログ("Started GET ...")は filtered_path を使う。アプリの設定(パラメータの伏せ字)を渡して確かめる。
      rack_request = Rack::MockRequest.env_for("/business/project_invitation?token=secret-token").merge(Rails.application.env_config)
      expect(ActionDispatch::Request.new(rack_request).filtered_path).to eq "/business/project_invitation?token=[FILTERED]"
    end
  end

  describe "有効な招待からの参加(ログイン済み)" do
    it "招待リンクを開いて「参加する」を押すと、親コミュニティに入らずにプロジェクトへ参加し、プロジェクトへ進む" do
      _link, token = issue_link
      sign_in invitee
      open_link(self, token)
      expect(response).to have_http_status(:ok)
      expect(doc.at_css("#invite-title").text).to eq "ひみつの企画"
      expect(response.body).to include("コミュニティ：親コミュニティ")
      expect(response.body).not_to include("内部の説明")
      # 開いただけでは参加しない。
      expect(invitee.business_project_participant?(secret)).to be false

      post accept_business_project_invitation_path
      expect(response).to redirect_to(business_project_path(secret))
      expect(invitee.business_project_participant?(secret)).to be true
      expect(invitee.business_community_member?(community)).to be false
      expect(secret.project_invitation_links.last!.used_count).to eq 1

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(doc.at_css("#threads")).to be_present
      expect(doc.css("#members .ba-person__name").map(&:text)).to include("招待された人")

      # 親コミュニティの会話・ほかのプロジェクトは見えないまま。
      get business_community_path(community)
      expect(response.body).not_to include("限定公開の企画", "通常公開の企画")
      sign_in invitee
      expect { get business_project_path(Project.create!(community: community, customer: owner, title: "別のひみつ", visibility: :private)) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end

    it "スレッドへ投稿でき、参加をメンバー(管理者)へ通知する" do
      _link, token = issue_link
      sign_in invitee
      open_link(self, token)
      expect { post accept_business_project_invitation_path }.to change { Notification.where(action: "project_joined", visited: owner).count }.by(1)

      post business_project_thread_project_chats_path(secret, general_thread), params: { project_chat: { body: "よろしくお願いします" } }
      expect(ProjectChat.where(project: secret, customer: invitee).pluck(:body)).to eq ["よろしくお願いします"]
    end

    it "同じリンクを複数人が使える。参加済みの人がもう一度開くとプロジェクトへ進むだけ" do
      _link, token = issue_link
      second = create(:customer, domain_name: "business", onboarding_done: true)
      [invitee, second].each do |customer|
        sign_in customer
        open_link(self, token)
        post accept_business_project_invitation_path
      end
      expect(secret.project_invitation_links.last!.used_count).to eq 2

      sign_in invitee
      get business_project_invitation_path(token: token)
      follow_redirect!
      expect(response).to redirect_to(business_project_path(secret))
      expect(secret.project_invitation_links.last!.used_count).to eq 2
    end

    it "アクセス停止中の人は参加できない" do
      _link, token = issue_link
      ProjectAccessSuspension.create!(project: secret, customer: invitee, suspended_by: owner)
      sign_in invitee
      open_link(self, token)
      expect(response.body).to include("アクセスが停止されているため、参加できません")
      post accept_business_project_invitation_path
      expect(invitee.business_project_participant?(secret)).to be false
    end

    it "未ログインで開くとログインを案内し、ログイン後に受け入れ画面へ戻る。参加後の通常ログインでは転送しない" do
      _link, token = issue_link
      open_link(self, token)
      expect(response.body).to include("ひみつの企画", "ログインして参加する", "新規登録して参加する")

      post business_customer_session_path, params: { customer: { email: invitee.email, password: "password" } }
      expect(response).to redirect_to(business_project_invitation_path)
      follow_redirect!
      expect(response.body).to include("参加する")
      post accept_business_project_invitation_path
      expect(response).to redirect_to(business_project_path(secret))

      delete destroy_customer_session_path
      post business_customer_session_path, params: { customer: { email: invitee.email, password: "password" } }
      expect(response).to redirect_to(business_root_path)
    end
  end

  describe "期限切れ・無効化・削除済みの招待" do
    it "期限切れ・無効化済み・存在しないリンクは案内を出し、参加させない(プロジェクト名は出さない)" do
      expired_link, expired_token = issue_link(expiry_days: 1)
      travel_to(2.days.from_now) do
        sign_in invitee
        open_link(self, expired_token)
        expect(response).to have_http_status(:gone)
        expect(response.body).to include("有効期限が切れています")
        expect(response.body).not_to include("ひみつの企画")
        post accept_business_project_invitation_path
        expect(response).to have_http_status(:not_found)
      end
      expect(expired_link.reload.used_count).to eq 0

      _link, token = issue_link
      ProjectInvitationLink.revoke_all!(secret)
      open_link(self, token)
      expect(response).to have_http_status(:gone)
      expect(response.body).to include("無効になっています")

      get business_project_invitation_path(token: "not-a-real-token")
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("招待リンクが見つかりません")
      expect(invitee.business_project_participant?(secret)).to be false
    end

    it "受け入れ画面を開いた後に無効化されたら、「参加する」を押しても参加しない" do
      _link, token = issue_link
      sign_in invitee
      open_link(self, token)
      ProjectInvitationLink.revoke_all!(secret)
      post accept_business_project_invitation_path
      expect(response).to have_http_status(:gone)
      expect(invitee.business_project_participant?(secret)).to be false
    end

    it "プロジェクトが削除されたリンクは「見つかりません」と案内する" do
      _link, token = issue_link
      secret.destroy!
      get business_project_invitation_path(token: token)
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("プロジェクトが削除された可能性があります")
    end
  end

  describe "アカウント未作成の人(招待リンク → 新規登録 → 確認メール → オンボーディング)" do
    def register(email)
      post business_customer_registration_path, params: {
        customer: { email: email, password: "password", password_confirmation: "password", name: "新しい人" }
      }
      expect(response).to redirect_to(new_business_customer_session_path)
      Customer.find_by!(email: email)
    end

    def go_through_onboarding(client)
      client.get onboarding_step1_path
      client.get onboarding_step2_path
      client.get onboarding_step3_path
      client.patch onboarding_complete_path
    end

    it "確認メールを別のブラウザで開いても、オンボーディング完了時に参加が成立してプロジェクトへ進み、次のログインでは転送しない" do
      link, token = issue_link
      open_link(self, token)
      newcomer = register("private-invite@example.com")
      expect(newcomer.business_signup_invitation).to have_attributes(target_type: "Project", target_id: secret.id, project_invitation_link_id: link.id)

      other_browser = open_session
      other_browser.get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
      expect(redirected_path(other_browser)).to eq onboarding_step1_path
      go_through_onboarding(other_browser)
      expect(redirected_path(other_browser)).to eq business_project_path(secret)

      expect(newcomer.reload.business_project_participant?(secret)).to be true
      expect(newcomer.business_community_member?(community)).to be false
      expect(BusinessSignupInvitation.exists?(customer_id: newcomer.id)).to be false
      expect(link.reload.used_count).to eq 1

      other_browser.follow_redirect!
      expect(other_browser.response).to have_http_status(:ok)
      expect(other_browser.response.body).to include("ひみつの企画")

      other_browser.delete destroy_customer_session_path
      other_browser.post business_customer_session_path, params: { customer: { email: newcomer.email, password: "password" } }
      expect(redirected_path(other_browser)).to eq business_root_path
    end

    it "期限内に登録を始めていれば、確認・オンボーディングが期限後でも参加できる" do
      link, token = issue_link(expiry_days: 1)
      newcomer = nil
      # 期限の直前に開いて登録し、期限の後に確認メール(有効期限は Devise の confirm_within = 1日)を開く。
      travel_to(23.hours.from_now) do
        open_link(self, token)
        newcomer = register("late-confirm@example.com")
      end

      travel_to(26.hours.from_now) do
        expect(link.reload.status).to eq :expired
        get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
        go_through_onboarding(self)
        expect(response).to redirect_to(business_project_path(secret))
        expect(newcomer.reload.business_project_participant?(secret)).to be true
      end
    end

    it "登録後にリンクが無効化されていたら、参加させずに案内を出す" do
      _link, token = issue_link
      open_link(self, token)
      newcomer = register("revoked-after-signup@example.com")
      ProjectInvitationLink.revoke_all!(secret)

      get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
      go_through_onboarding(self)
      expect(response).to redirect_to(business_root_path)
      expect(flash[:alert]).to include("招待リンクが無効になっているため、プロジェクトに参加できませんでした")
      expect(flash[:alert]).not_to include("ひみつの企画")
      expect(newcomer.reload.business_project_participant?(secret)).to be false
    end

    it "プライベートの詳細URLを未ログインで開いて登録しても招待にはならず、プロジェクト名も案内に出ない" do
      get business_project_path(secret)
      expect(response).to redirect_to(new_business_customer_session_url)
      newcomer = register("detail-url@example.com")
      expect(BusinessSignupInvitation.exists?(customer_id: newcomer.id)).to be false

      get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
      go_through_onboarding(self)
      expect(flash.to_h.values.join).not_to include("ひみつの企画")
      expect(newcomer.reload.business_project_participant?(secret)).to be false
      # 戻り先が詳細URLのままでも、開くと存在しない場合と同じ 404 になる。
      expect { follow_redirect! }.to raise_error(ActiveRecord::RecordNotFound) if response.redirect? && response.location.include?(business_project_path(secret))
    end
  end

  describe "公開範囲の変更" do
    before do
      ProjectMember.create!(project: listed, customer: community_member)
      ProjectJoinRequest.create!(project: listed, customer: create(:customer, domain_name: "business").tap { |c| CommunityCustomer.create!(community: community, customer: c) })
    end

    it "通常公開 → プライベートは確認画面を通し、メンバーは残して承認待ちの申請を取り消す" do
      sign_in owner
      patch business_project_path(listed), params: { project: { title: "名前も変更", visibility: "private" } }
      expect(response).to redirect_to(edit_business_project_visibility_path(listed, to: "private"))
      # 公開範囲以外は保存し、公開範囲はまだ変えない。
      expect(listed.reload).to have_attributes(title: "名前も変更", visibility: "listed")

      follow_redirect!
      expect(response.body).to include("承認待ちの参加申請1件は取り消されます", "いまのメンバー1人の参加はそのままです")

      patch business_project_visibility_path(listed), params: { to: "private" }
      expect(listed.reload).to be_visibility_listed

      patch business_project_visibility_path(listed), params: { to: "private", confirmed: "1" }
      expect(response).to redirect_to(business_project_path(listed))
      expect(listed.reload).to be_visibility_private
      expect(listed.project_join_requests).to be_empty
      expect(community_member.business_project_participant?(listed)).to be true

      sign_in community_member
      get business_project_path(listed)
      expect(response).to have_http_status(:ok)
    end

    it "プライベート → 通常公開・限定公開は「閲覧できる範囲が広がる」ことを確認画面に明記し、招待リンクを無効にする" do
      ProjectMember.create!(project: secret, customer: invitee)
      _link, token = issue_link

      %w[listed unlisted].each do |target|
        sign_in owner
        get edit_business_project_visibility_path(secret, to: target)
        expect(response).to have_http_status(:ok)
        warning = doc.at_css(".ba-visibility-confirm__warning").text
        expect(warning).to include("閲覧できる範囲が広がります", "コミュニティ「親コミュニティ」の参加者にも見えるようになります")
        expect(response.body).to include("コミュニティに参加していないメンバー1人は、このプロジェクトを見られなくなります", "招待リンクはすべて無効になります")
      end

      patch business_project_visibility_path(secret), params: { to: "unlisted", confirmed: "1" }
      expect(secret.reload).to be_visibility_unlisted
      expect(ProjectInvitationLink.find_by_token(token).status).to eq :revoked

      sign_in community_member
      get business_project_path(secret)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("内部の説明")
    end

    it "運営者・作成者はプライベートへの変更・プライベートからの変更をできない(選択肢にも出さない)" do
      [co_manager, creator].each do |customer|
        sign_in customer
        get edit_business_project_path(secret)
        expect(doc.at_css("select#project_visibility")).to be_nil
        expect(doc.at_css("#project-visibility .ba-static").text).to eq "プライベート"

        patch business_project_path(secret), params: { project: { visibility: "listed" } }
        expect(secret.reload).to be_visibility_private

        get edit_business_project_visibility_path(secret, to: "listed")
        expect(response).to redirect_to(business_project_path(secret))
        patch business_project_visibility_path(secret), params: { to: "listed", confirmed: "1" }
        expect(secret.reload).to be_visibility_private
      end

      sign_in co_manager
      get edit_business_project_path(listed)
      expect(doc.css("select#project_visibility option").map { |o| o["value"] }).to eq %w[listed unlisted]
      patch business_project_path(listed), params: { project: { visibility: "private" } }
      expect(listed.reload).to be_visibility_listed
    end

    it "権限の無い人がプライベートで新規作成しようとしても作成しない(通常公開にも置き換えない)" do
      allow_any_instance_of(Customer).to receive(:can_create_project_for?).and_return(true)
      sign_in co_manager
      get new_business_project_path(community_id: community.id)
      expect(doc.css("select#project_visibility option").map { |o| o["value"] }).to eq %w[listed unlisted]

      expect {
        post business_projects_path, params: { project: { community_id: community.id, title: "勝手なひみつ", visibility: "private" } }
      }.not_to change(Project, :count)
      expect(response.body).to include("プライベートのプロジェクトを作成できるのは")
    end

    it "通常公開 ⇔ 限定公開は従来どおり確認画面なしで保存する" do
      sign_in co_manager
      patch business_project_path(listed), params: { project: { visibility: "unlisted" } }
      expect(response).to redirect_to(business_project_path(listed))
      expect(listed.reload).to be_visibility_unlisted
    end
  end

  describe "親コミュニティとの関係" do
    before { ProjectMember.create!(project: secret, customer: invitee) }

    it "招待で参加した人が後からコミュニティに参加・退会しても、プライベートの参加は残る" do
      community.update!(join_approval_mode: :auto)
      expect(Business::Memberships::JoinCommunity.call(community: community, customer: invitee)).to eq :joined
      expect(invitee.business_project_participant?(secret)).to be true

      Business::Memberships::RevokeCommunityAccess.call(community: community, customer: invitee)
      expect(invitee.business_project_participant?(secret)).to be true
    end

    it "親コミュニティでアクセス停止になると、プライベートも閲覧できなくなる(参加の行も消す)" do
      Business::Memberships::RevokeCommunityAccess.call(community: community, customer: invitee, suspend: true, actor: owner)
      expect(invitee.business_project_participant?(secret)).to be false
      expect(secret.project_members.where(customer: invitee)).to be_empty
    end

    it "退出するとプロジェクトを開けなくなるため、ホームへ戻す" do
      sign_in invitee
      delete leave_business_project_path(secret)
      expect(response).to redirect_to(business_root_path)
      expect(invitee.business_project_participant?(secret)).to be false
    end

    it "通知の宛先・メンバー一覧には、コミュニティ未参加の招待メンバーも含める" do
      expect(secret.accessible_customers).to include(invitee)
      expect(secret.participating_members).to include(invitee)
      expect(secret.thread_post_notification_recipients).to include(invitee)
      expect(Business::Memberships::ProjectStatuses.for(customer: invitee, project: secret)).to eq :member
    end
  end
end
