require "rails_helper"

# コミュニティ・プロジェクトの「招待用URL」。通常画面のURLを共有するだけで、参加・閲覧の条件は変えない。
# 未ログインで開いた人は、ログイン・確認メール・利用開始・オンボーディングの後に、可能な範囲で元のページへ戻す。
RSpec.describe "Business 招待用URL", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:owner) { create(:customer, domain_name: "business", name: "運営者", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "共有テストコミュニティ") }
  let(:project) { Project.create!(community: community, customer: owner, title: "共有テスト企画", description: "説明") }
  let(:member) { create(:customer, domain_name: "business", name: "参加者さん", onboarding_done: true) }
  let(:outsider) { create(:customer, domain_name: "business", name: "未参加さん", onboarding_done: true) }

  let!(:secrets) do
    CommunityCustomer.create!(community: community, customer: owner)
    CommunityCustomer.create!(community: community, customer: member)
    ProjectMember.create!(project: project, customer: member)
    thread = ProjectThread.create!(project: project, customer: member, title: "内部スレッドの題名")
    ProjectChat.create!(project: project, project_thread: thread, customer: member, body: "内部メッセージ本文")
    CommunityPost.create!(community: community, customer: member, body: "コミュニティ内の秘密の会話")
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def share_url_field
    doc.at_css("[data-share-url]")
  end

  def sign_in_via(path, customer)
    post path, params: { customer: { email: customer.email, password: "password" } }
  end

  describe "通常画面の表示" do
    it "コミュニティ・プロジェクトの通常画面に、その画面のURLだけを出す(検索条件・会員IDを含めない)" do
      sign_in member

      get business_community_path(community, keyword: "検索語", customer_id: member.id)
      expect(share_url_field["value"]).to eq "http://localhost:3000/business/communities/#{community.id}"
      expect(share_url_field.key?("readonly")).to be true
      expect(doc.at_css("[data-share-copy]").text.strip).to eq "URLをコピー"
      expect(doc.at_css(".ba-share__status")["role"]).to eq "status"

      get business_project_path(project)
      expect(share_url_field["value"]).to eq "http://localhost:3000/business/projects/#{project.id}"
    end

    it "コピーのボタンは JavaScript が動くまで隠し、URL欄だけで手動コピーできる" do
      sign_in member
      get business_community_path(community)

      expect(doc.at_css("[data-share-copy][hidden]")).to be_present
      expect(doc.at_css(%(label[for="#{share_url_field["id"]}"]))).to be_present
    end

    it "リクエストの Host を使わず、設定した正規ホスト(本番は HTTPS)で組み立てる" do
      allow(Rails.application.config.x).to receive(:business_share_url_options)
        .and_return({ protocol: "https", host: "be-my-style.com", port: nil })
      sign_in member

      host! "evil.example:8080"
      get business_project_path(project)

      expect(share_url_field["value"]).to eq "https://be-my-style.com/business/projects/#{project.id}"
      expect(response.body).not_to include("evil.example")
    end

    it "編集・メンバー管理の画面には出さない" do
      sign_in owner

      [edit_business_community_path(community), business_permits_path(community),
       edit_business_project_path(project), members_business_project_path(project)].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect(share_url_field).to be_nil, path
      end
    end

    it "参加方式に合った説明を出す(コミュニティ・プロジェクト)" do
      sign_in member

      get business_community_path(community)
      expect(doc.at_css(".ba-share__note").text).to include("ログイン（未登録なら新規登録）が必要", "参加には運営者の承認が必要")

      community.update!(join_approval_mode: :auto)
      get business_community_path(community)
      expect(doc.at_css(".ba-share__note").text).to include("「参加する」を押すとすぐに参加できます")

      get business_project_path(project)
      expect(doc.at_css(".ba-share__note").text).to include("先にコミュニティ「共有テストコミュニティ」への参加が必要", "プロジェクト管理者の承認が必要")
    end
  end

  describe "共有URLを開いた人ごとの見え方" do
    it "未ログインはどちらも Business のログインへ案内し、中身を出さない" do
      [business_community_path(community), business_project_path(project)].each do |path|
        get path
        expect(response).to redirect_to(new_business_customer_session_url)
        follow_redirect!
        expect(response.body).not_to include("内部メッセージ本文", "コミュニティ内の秘密の会話", "参加者さん")
      end
    end

    it "未参加・承認待ち・停止中は、コミュニティの紹介だけで会話・メンバー・プロジェクトを出さない" do
      pending = create(:customer, domain_name: "business", onboarding_done: true)
      Permit.create!(community: community, customer: pending)
      suspended = create(:customer, domain_name: "business", onboarding_done: true)
      CommunityAccessSuspension.create!(community: community, customer: suspended)

      { outsider => "参加を申請する", pending => "承認待ち", suspended => "アクセス停止中" }.each do |viewer, label|
        sign_in viewer
        get business_community_path(community)

        expect(response).to have_http_status(:ok)
        expect(doc.at_css("#community-join").text).to include(label)
        expect(response.body).not_to include("コミュニティ内の秘密の会話", "共有テスト企画", "参加者さん")
        expect(doc.at_css("#timeline, #members, #projects")).to be_nil
      end
    end

    it "親コミュニティ未参加でプロジェクトのURLを開くと、先にコミュニティの参加案内を出す" do
      sign_in outsider
      get business_project_path(project)

      expect(response).to redirect_to(business_community_path(community))
      follow_redirect!
      expect(response.body).to include("先にコミュニティへの参加が必要です")
      expect(doc.at_css("#community-join a[data-method='post']").text.strip).to eq "参加を申請する"
      expect(response.body).not_to include("内部スレッドの題名", "内部メッセージ本文")
    end

    it "コミュニティ参加済みでもプロジェクト未参加・承認待ち・停止中なら、スレッド・メンバー・添付を出さない" do
      CommunityCustomer.create!(community: community, customer: outsider)
      sign_in outsider

      get business_project_path(project)
      expect(doc.at_css("#project-join a[data-method='post']").text.strip).to eq "参加を申請する"
      expect(response.body).not_to include("内部スレッドの題名", "内部メッセージ本文", "参加者さん")

      ProjectJoinRequest.create!(project: project, customer: outsider)
      get business_project_path(project)
      expect(doc.at_css("#project-join").text).to include("承認待ち")
      expect(response.body).not_to include("内部スレッドの題名")

      ProjectJoinRequest.delete_all
      ProjectAccessSuspension.create!(project: project, customer: outsider)
      get business_project_path(project)
      expect(doc.at_css("#project-join").text).to include("アクセス停止中")
      expect(response.body).not_to include("内部スレッドの題名")

      get business_project_threads_path(project)
      expect(response).to redirect_to(business_project_path(project))
    end

    it "参加者には通常どおり中身を出す" do
      sign_in member
      get business_project_path(project)

      expect(response.body).to include("内部スレッドの題名")
    end

    it "URLを開いただけでは参加・申請しない" do
      sign_in outsider

      expect do
        get business_community_path(community)
        get business_project_path(project)
      end.not_to change { [Permit.count, CommunityCustomer.count, ProjectJoinRequest.count, ProjectMember.count] }
    end
  end

  it "戻り先を使うすべての画面で、Business 内のパスだけを許し、外部・ログイン系・Business 以外は使わない" do
    controllers = [Public::SessionsController, Public::ConfirmationsController, Business::JoinsController, OnboardingsController]
    rejected = %w[//evil.example/business https://evil.example/business /business//evil.example /business\\evil
                  /public/lp /businessx /business/sign_in /business/sign_up?x=1 /business/join /business/password/new]
    accepted = ["/business", "/business/communities/1", "/business/projects/2?tab=threads"]

    controllers.each do |controller_class|
      controller = controller_class.new
      rejected.each { |path| expect(controller.send(:restorable_business_path?, path)).to be(false), "#{controller_class} #{path}" }
      accepted.each { |path| expect(controller.send(:restorable_business_path?, path)).to be(true), "#{controller_class} #{path}" }
    end
  end

  it "Business 未登録の人の案内はループしない(利用開始画面は転送せずに表示し、利用開始後は元のページを表示する)" do
    music_only = create(:customer, domain_name: "music", onboarding_done: true)
    sign_in music_only

    get business_community_path(community)
    expect(response).to redirect_to(business_join_path)
    get business_join_path
    expect(response).to have_http_status(:ok)
    post business_join_path
    expect(response).to redirect_to(business_community_path(community))
    get business_community_path(community)
    expect(response).to have_http_status(:ok)
    get business_join_path
    expect(response).to redirect_to(business_root_path)
  end

  describe "ログイン・登録のあとに元のページへ戻す" do
    it "未ログインで開いたプロジェクトへ、Business のログイン後に戻る" do
      get business_project_path(project)
      sign_in_via(business_customer_session_path, member)

      expect(response).to redirect_to(business_project_path(project))
    end

    it "オンボーディング未完了なら先にオンボーディングへ進め、完了後に元のページへ戻す" do
      newcomer = create(:customer, domain_name: "business", onboarding_done: false)

      get business_community_path(community)
      sign_in_via(business_customer_session_path, newcomer)
      expect(response).to redirect_to(onboarding_step1_path)

      get onboarding_step2_path
      get onboarding_step3_path
      patch onboarding_complete_path
      expect(response).to redirect_to(business_community_path(community))

      # 1回使った戻り先は残さない。
      newcomer.update!(onboarding_done: false)
      patch onboarding_complete_path
      expect(response).to redirect_to(business_root_path)
    end

    it "Business 未登録(音楽だけ)の人は利用開始の案内を経て、元のページへ戻る" do
      music_only = create(:customer, domain_name: "music", onboarding_done: true)

      get business_community_path(community)
      sign_in_via(business_customer_session_path, music_only)
      expect(response).to redirect_to(business_join_path)

      post business_join_path
      expect(response).to redirect_to(business_community_path(community))
      expect(music_only.reload.business_user?).to be true
    end

    it "新規登録して同じブラウザで確認メールのリンクを開くと、元のページへ戻る" do
      get business_project_path(project)
      expect do
        post business_customer_registration_path, params: {
          customer: { email: "share-newcomer@example.com", password: "password", password_confirmation: "password", name: "新しい人" }
        }
      end.to change(Customer, :count).by(1)
      expect(response).to redirect_to(new_business_customer_session_path)

      newcomer = Customer.find_by!(email: "share-newcomer@example.com")
      expect(newcomer.business_user?).to be true
      get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)

      expect(response).to redirect_to(business_project_path(project))
      follow_redirect!
      # 親コミュニティ未参加なので、プロジェクトの中身ではなくコミュニティの参加案内になる。
      expect(response).to redirect_to(business_community_path(community))
    end

    it "確認メールのリンクを別のブラウザで開くと、そのブラウザでは Business ホームへ進む(戻り先はセッションに無い)" do
      get business_project_path(project)
      post business_customer_registration_path, params: {
        customer: { email: "other-browser@example.com", password: "password", password_confirmation: "password", name: "別ブラウザの人" }
      }
      token = Customer.find_by!(email: "other-browser@example.com").confirmation_token

      # 別のブラウザ(LINE 内ブラウザ → メールアプリ → Safari など)は、Cookie(セッション)を持たない別のセッションになる。
      other_browser = open_session
      other_browser.get customer_confirmation_path(confirmation_token: token)
      expect(other_browser.response).to have_http_status(:found)
      expect(URI.parse(other_browser.response.location).path).to eq business_root_path

      # 元のブラウザ(共有URLを開いたブラウザ)に戻ってログインすると、オンボーディングの後に元のページへ戻る。
      sign_in_via(business_customer_session_path, Customer.find_by!(email: "other-browser@example.com"))
      expect(response).to redirect_to(onboarding_step1_path)
      patch onboarding_complete_path
      expect(response).to redirect_to(business_project_path(project))
    end
  end
end
