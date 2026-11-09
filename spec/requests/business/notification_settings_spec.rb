require "rails_helper"

# Business(NAKAMA)の通知設定: メール通知・画面内の通知を本人がそれぞれオン・オフする。
RSpec.describe "Business 通知設定", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:me) { create(:customer, name: "受け取る人", domain_name: "business", confirm_mail: true) }
  let(:follower) { create(:customer, name: "フォローする人", domain_name: "business") }
  let(:stranger) { create(:customer, name: "他の人", domain_name: "business", confirm_mail: true) }

  def save_setting(email:, in_app:)
    patch business_notification_setting_path,
          params: { business_notification_setting: { email_enabled: email ? "1" : "0", in_app_enabled: in_app ? "1" : "0" } }
  end

  def page
    Nokogiri::HTML(response.body)
  end

  def status_texts
    get business_notification_setting_path
    page.css(".notification-settings__status strong").map(&:text)
  end

  def bell_count
    get business_notification_setting_path
    page.at_css(".ba-sidenav .ba-nav-badge")&.text.to_i
  end

  def notification_list_text
    get business_notifications_path
    page.at_css(".ba-notifications")&.text.to_s
  end

  def follow_me_as(customer)
    sign_in customer
    post business_customer_relationships_path(me)
    sign_out customer
  end

  describe "設定画面" do
    it "ログインしていなければ設定を表示・変更できない" do
      get business_notification_setting_path
      expect(response).to have_http_status(:redirect)

      patch business_notification_setting_path, params: { business_notification_setting: { email_enabled: "0" } }
      expect(response).to have_http_status(:redirect)
      expect(BusinessNotificationSetting.count).to eq 0
    end

    it "未保存の会員は、従来のメール受信設定(confirm_mail)と画面内オンを引き継いで表示する" do
      sign_in me
      expect(status_texts).to eq %w[オン オン]

      quiet = create(:customer, domain_name: "business", confirm_mail: false)
      sign_out me
      sign_in quiet
      expect(status_texts).to eq %w[オフ オン]
      expect(page.at_css("#business_notification_setting_email_enabled")["checked"]).to be_nil
    end

    it "保存すると結果が表示され、再読み込み後も反映される。音楽側の confirm_mail は変わらない" do
      sign_in me
      save_setting(email: false, in_app: false)

      expect(response).to redirect_to(business_notification_setting_path)
      follow_redirect!
      expect(response.body).to include("通知設定を保存しました")
      expect(status_texts).to eq %w[オフ オフ]
      expect(me.reload.confirm_mail).to eq true

      save_setting(email: true, in_app: true)
      expect(status_texts).to eq %w[オン オン]
    end

    it "保存後は音楽側で confirm_mail を変えても Business の設定は変わらない" do
      sign_in me
      save_setting(email: true, in_app: true)
      me.update!(confirm_mail: false)

      expect(me.reload.business_email_notifications_enabled?).to eq true
    end

    it "本人以外の設定は変更できない(他人の ID を送っても自分の設定だけが変わる)" do
      sign_in stranger
      patch business_notification_setting_path,
            params: { id: me.id, customer_id: me.id,
                      business_notification_setting: { customer_id: me.id, email_enabled: "0", in_app_enabled: "0" } }

      expect(me.reload.business_notification_setting).to be_nil
      expect(me.business_email_notifications_enabled?).to eq true
      expect(me.business_in_app_notifications_enabled?).to eq true
      expect(stranger.reload.business_notification_setting).to have_attributes(email_enabled: false, in_app_enabled: false)
    end

    it "マイページ(本人のみ)と通知一覧から設定画面へ行ける" do
      sign_in me
      get business_customer_path(me)
      expect(page.at_css(".ba-user__action a[href='#{business_notification_setting_path}']")).to be_present

      get business_customer_path(stranger)
      expect(page.at_css(".ba-user__action a[href='#{business_notification_setting_path}']")).to be_nil

      get business_notifications_path
      expect(page.at_css(".ba-page-header a[href='#{business_notification_setting_path}']")).to be_present
    end
  end

  describe "フォロー" do
    it "既定(両方オン)ではメールが届き、ベル・通知一覧に出る" do
      expect { follow_me_as(follower) }.to have_enqueued_mail(CustomerMailer, :business_follow_mail)

      sign_in me
      expect(bell_count).to eq 1
      expect(notification_list_text).to include("フォローする人がフォローしました")
    end

    it "メールだけオフ: メールは届かず、画面内には出る" do
      sign_in me
      save_setting(email: false, in_app: true)
      sign_out me

      expect { follow_me_as(follower) }.not_to have_enqueued_mail(CustomerMailer, :business_follow_mail)

      sign_in me
      expect(bell_count).to eq 1
      expect(notification_list_text).to include("フォローする人がフォローしました")
    end

    it "画面内だけオフ: メールは届き、ベル・通知一覧には出ない。過去の通知は残る" do
      old_follower = create(:customer, name: "前からの人", domain_name: "business")
      follow_me_as(old_follower)

      sign_in me
      save_setting(email: true, in_app: false)
      sign_out me

      expect { follow_me_as(follower) }.to have_enqueued_mail(CustomerMailer, :business_follow_mail)
      expect(Notification.find_by(visitor: follower, visited: me, action: "follow")).to have_attributes(hidden_in_app: true)

      sign_in me
      expect(bell_count).to eq 1 # 前からの通知(未読)だけ
      text = notification_list_text
      expect(text).to include("前からの人がフォローしました")
      expect(text).not_to include("フォローする人がフォローしました")
    end

    it "オンに戻すと、その後の通知はメール・画面内とも届く" do
      sign_in me
      save_setting(email: false, in_app: false)
      sign_out me
      follow_me_as(follower)

      sign_in me
      save_setting(email: true, in_app: true)
      sign_out me

      later = create(:customer, name: "後からの人", domain_name: "business")
      expect { follow_me_as(later) }.to have_enqueued_mail(CustomerMailer, :business_follow_mail)

      sign_in me
      text = notification_list_text
      expect(text).to include("後からの人がフォローしました")
      expect(text).not_to include("フォローする人がフォローしました")
    end
  end

  describe "スレッド投稿" do
    let(:operator) { create(:customer, domain_name: "business") }
    let(:community) { create(:community, name: "企画部", owner: operator, domain: business_domain) }
    let(:poster) { create(:customer, name: "投稿した人", domain_name: "business") }
    let(:project) { Project.create!(community: community, customer: poster, title: "新サービス企画") }
    let(:thread_record) { ProjectThread.create!(project: project, customer: poster, title: "デザイン相談") }

    before do
      [operator, poster, me].each { |customer| CommunityCustomer.find_or_create_by!(community: community, customer: customer) }
      [poster, me].each { |customer| ProjectMember.find_or_create_by!(project: project, customer: customer) }
    end

    def post_to_thread
      sign_in poster
      post business_project_thread_project_chats_path(project, thread_record), params: { project_chat: { body: "ラフ案です" } }
      sign_out poster
    end

    def mails_to_me
      ActionMailer::Base.deliveries.select { |mail| mail.to.include?(me.email) }
    end

    it "画面内オフ・メールオン: 通知の作成を起点にしたメールは届き、画面内には出ない" do
      sign_in me
      save_setting(email: true, in_app: false)
      sign_out me

      perform_enqueued_jobs { post_to_thread }

      expect(mails_to_me.size).to eq 1
      expect(Notification.find_by!(visited: me, action: "project_message")).to have_attributes(hidden_in_app: true)
      sign_in me
      expect(bell_count).to eq 0
      expect(notification_list_text).not_to include("新サービス企画")
    end

    it "メールオフ・画面内オン: メールは届かず、画面内には出る" do
      sign_in me
      save_setting(email: false, in_app: true)
      sign_out me

      perform_enqueued_jobs { post_to_thread }

      expect(mails_to_me).to be_empty
      sign_in me
      expect(bell_count).to eq 1
      expect(notification_list_text).to include("新サービス企画")
    end

    it "送信までにメールをオフにした場合は送らない" do
      post_to_thread
      sign_in me
      save_setting(email: false, in_app: true)

      expect { perform_enqueued_jobs }.not_to change { mails_to_me.size }
    end
  end

  describe "設定に関係なく動くもの" do
    before do
      sign_in me
      save_setting(email: false, in_app: false)
      sign_out me
    end

    it "パスワード再設定メールは届く" do
      expect do
        perform_enqueued_jobs { me.send_reset_password_instructions }
      end.to change { ActionMailer::Base.deliveries.count { |mail| mail.to.include?(me.email) } }.by(1)
    end

    it "参加申請・承認そのものは行われる(お知らせのメールだけ止まる)" do
      community = create(:community, owner: me, domain: business_domain, join_approval_mode: :manual)
      CommunityCustomer.find_or_create_by!(community: community, customer: me)

      sign_in follower
      expect { post business_community_permit_path(community) }
        .not_to have_enqueued_mail(CustomerMailer, :business_request_mail)
      expect(Permit.exists?(community: community, customer: follower)).to eq true
      expect(Notification.find_by(visited: me, action: "request")).to have_attributes(hidden_in_app: true)
      sign_out follower

      sign_in me
      expect { post business_community_community_customers_path(community, customer_id: follower.id) }
        .to have_enqueued_mail(CustomerMailer, :business_accept_mail)
      expect(CommunityCustomer.exists?(community: community, customer: follower)).to eq true
    end
  end
end
