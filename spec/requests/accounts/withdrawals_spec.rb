require "rails_helper"

RSpec.describe "アカウントの退会", type: :request do
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:password) { "password123" }
  let(:session_cookie_key) { Rails.application.config.session_options[:key] }
  let(:customer) do
    create(:customer, domain_name: "music", password: password, password_confirmation: password, onboarding_done: true)
  end

  def withdraw!(current_password: password, **params)
    post account_withdrawal_path, params: { current_password: current_password, **params }
  end

  def sign_in_from_form(target = customer, remember: "1")
    post customer_session_path, params: { customer: { email: target.email, password: password, remember_me: remember } }
  end

  describe "未ログイン" do
    it "確認画面はログイン画面へ戻し、確定も受け付けない" do
      get new_account_withdrawal_path
      expect(response).to redirect_to(new_customer_session_url)

      customer
      expect { withdraw! }.not_to(change { customer.reload.withdrawn_at })
      expect(response).to redirect_to(new_customer_session_url)
    end

    it "完了画面は表示できる(内容は案内のみ)" do
      get complete_account_withdrawal_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("退会が完了しました")
    end
  end

  describe "確認画面" do
    before { sign_in customer }

    it "開いただけでは退会せず、退会後の扱いを説明する" do
      get new_account_withdrawal_path

      expect(response).to have_http_status(:ok)
      expect(customer.reload.withdrawn_at).to be_nil
      body = response.body
      expect(body).to include("BeMyStyleを退会する")
      expect(body).to include("ログインできなくなります")
      expect(body).to include("退会済みユーザー")
      expect(body).to include("退会完了のメールは送りません")
      expect(body).to include("復元できません")
      expect(body).to include("コミュニティを退会")
      expect(body).to include("退会を確定する")
      expect(body).to include("戻る")
      expect(body).not_to include("NAKAMAとBeMyStyleの両方が利用できなくなります")
    end

    it "NAKAMA の入口から開いても、アカウント全体の退会であることを説明する" do
      get new_account_withdrawal_path(from: "business")

      expect(response).to have_http_status(:ok)
      expect(customer.reload.withdrawn_at).to be_nil
      document = Nokogiri::HTML(response.body)
      expect(document.at_css("h1").text.strip).to eq("BeMyStyleを退会する")
      expect(document.at_css(".account-withdrawal__lead").text).to include("すべてのサービスが使えなくなります")
      note = document.at_css(".account-withdrawal__note--business")
      expect(note.text.strip).to eq("退会すると、NAKAMAとBeMyStyleの両方が利用できなくなります。")
      expect(document.at_css("a[href='#{business_root_path}']")).to be_present
    end

    it "取消期限前の開催前イベントのエントリーを、退会で取り消すものとして表示する" do
      community = create(:community, owner_id: create(:customer).id)
      event = build(:event, customer: create(:customer), community: community, event_name: "秋のセッション",
                            event_start_time: 30.days.from_now, event_end_time: 30.days.from_now + 3.hours,
                            event_entry_deadline: 20.days.from_now)
      event.songs << build(:song, event: event, song_name: "夜明けの歌")
      event.save!
      join_part = create(:join_part, song: event.songs.first, join_part_name: "ベース")
      create(:join_part_customer, customer: customer, join_part: join_part)

      get new_account_withdrawal_path

      expect(response.body).to include("退会と同時に取り消します")
      expect(response.body).to include("秋のセッション / 夜明けの歌(ベース)")
    end

    it "確定できない理由があれば、対象と解消方法を出し、確定ボタンを出さない" do
      owned = create(:community, owner_id: customer.id, name: "わたしのバンド部")

      get new_account_withdrawal_path

      expect(response.body).to include("オーナーになっているコミュニティがあります")
      expect(response.body).to include("わたしのバンド部")
      expect(response.body).to include("コミュニティを削除するか")
      expect(response.body).not_to include("退会を確定する")
      expect(owned.reload.owner_id).to eq(customer.id)
    end

    it "「戻る」は指定したサービスのトップへ。外部 URL は受け付けない" do
      get new_account_withdrawal_path(from: "business")
      expect(Nokogiri::HTML(response.body).at_css("a.account-withdrawal__back")["href"]).to eq(business_root_path)

      get new_account_withdrawal_path(from: "https://evil.example.com")
      expect(Nokogiri::HTML(response.body).at_css("a.account-withdrawal__back")["href"]).to eq(public_homes_top_path)
    end
  end

  describe "確定" do
    it "本人がパスワードを入力して確定すると、退会してログアウトし、完了画面へ進む" do
      sign_in customer

      withdraw!

      expect(response).to redirect_to(complete_account_withdrawal_path)
      expect(customer.reload).to be_withdrawn
      expect(customer.name).to eq("退会済みユーザー")

      follow_redirect!
      expect(response.body).to include("退会が完了しました")

      get public_notifications_path
      expect(response).to redirect_to(new_customer_session_url)
    end

    it "パスワードが違うと退会しない" do
      sign_in customer

      withdraw!(current_password: "wrong-password")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("パスワードが正しくありません")
      expect(customer.reload.withdrawn_at).to be_nil
    end

    it "ほかの会員の ID を送っても、ログイン中の本人だけが対象になる" do
      other = create(:customer)
      sign_in customer

      withdraw!(customer_id: other.id, id: other.id)

      expect(other.reload.withdrawn_at).to be_nil
      expect(customer.reload).to be_withdrawn
    end

    it "GET では退会しない(確定は POST のみ)" do
      sign_in customer

      expect { get account_withdrawal_path }.to raise_error(ActionController::RoutingError)
      expect(customer.reload.withdrawn_at).to be_nil
    end

    it "CSRF トークンのない送信は受け付けない" do
      sign_in customer
      ActionController::Base.allow_forgery_protection = true

      withdraw!
      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq CsrfRejectionRecovery::EXPIRED_FORM_MESSAGE
      expect(customer.reload.withdrawn_at).to be_nil
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "確定できない理由があれば 422 で案内し、退会しない" do
      create(:community, owner_id: customer.id)
      sign_in customer

      withdraw!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("退会を確定できない理由があります")
      expect(customer.reload.withdrawn_at).to be_nil
    end

    it "二重送信(2回目)でも壊れず、完了画面へ進む" do
      sign_in customer
      withdraw!
      first_email = customer.reload.email

      # 2回目の送信が1回目のコミット前に認証を通過した場合と同じ状況(本人として認証済みのまま確定処理へ進む)。
      result = Customers::Withdrawal::Execute.call(Customer.find(customer.id))

      expect(result).to be_already_withdrawn
      expect(customer.reload.email).to eq(first_email)
    end

    it "DB の更新に失敗したら、何も変えずに案内する" do
      sign_in customer
      allow(Customers::Withdrawal::Execute).to receive(:call).and_raise(ActiveRecord::StatementInvalid, "boom")

      withdraw!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("アカウントは変更していません")
      expect(customer.reload.withdrawn_at).to be_nil
    end
  end

  describe "退会後のログイン・セッション・トークン" do
    it "元のメールアドレスとパスワードではログインできない" do
      sign_in customer
      original_email = customer.email
      withdraw!

      post customer_session_path, params: { customer: { email: original_email, password: password } }

      get public_notifications_path
      expect(response).to redirect_to(new_customer_session_url)
    end

    # セッションは Cookie に保存されるため、退会前のセッション Cookie を戻すことで、
    # 別の端末・ブラウザに残っているログイン(同じ会員として認証済みのセッション)を再現する。
    it "別の端末・ブラウザに残っていたログインも使えなくなる" do
      sign_in_from_form(remember: "0")
      get public_notifications_path
      expect(response).to have_http_status(:ok)
      other_browser_session = cookies[session_cookie_key]

      withdraw!
      cookies[session_cookie_key] = other_browser_session

      get public_notifications_path
      expect(response).to redirect_to(new_customer_session_url)
    end

    it "保存していたログイン保持 Cookie を戻しても、ログインできない" do
      sign_in_from_form
      saved_token = cookies["remember_customer_token"]
      expect(saved_token).to be_present

      withdraw!
      cookies.delete(session_cookie_key)
      cookies["remember_customer_token"] = saved_token

      get public_notifications_path
      expect(response).to redirect_to(new_customer_session_url)
    end

    it "退会前に発行したパスワード再設定のトークンは使えない" do
      raw_token = customer.send_reset_password_instructions
      sign_in customer
      withdraw!
      encrypted_password = customer.reload.encrypted_password

      put customer_password_path, params: {
        customer: { reset_password_token: raw_token, password: "new-password", password_confirmation: "new-password" }
      }

      expect(customer.reload.encrypted_password).to eq(encrypted_password)
      get public_notifications_path
      expect(response).to redirect_to(new_customer_session_url)
    end

    it "退会前に発行したメール確認のトークンでは、確認もログインもできない" do
      unconfirmed = create(:customer, password: password, password_confirmation: password, confirmed_at: nil)
      raw_token = unconfirmed.confirmation_token
      expect(raw_token).to be_present
      Customers::Withdrawal::Execute.call(unconfirmed)

      get customer_confirmation_path(confirmation_token: raw_token)

      expect(unconfirmed.reload.confirmed_at).to be_nil
      get public_notifications_path
      expect(response).to redirect_to(new_customer_session_url)
    end

    it "パスワード再設定を申し込んでも、退会したアカウントへはメールを送らない" do
      sign_in customer
      original_email = customer.email
      withdraw!
      ActionMailer::Base.deliveries.clear

      post customer_password_path, params: { customer: { email: original_email } }

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "同じメールアドレスで新しく登録しても、以前の権限・予約済みの通知は引き継がない" do
      original_email = customer.email
      community = create(:community, owner_id: create(:customer).id)
      CommunityOwner.create!(customer: customer, community: community)
      invitation_event = build(:event, customer: create(:customer), community: community,
                                       event_start_time: 30.days.from_now, event_end_time: 30.days.from_now + 1.hour,
                                       event_entry_deadline: 20.days.from_now)
      invitation_event.songs << build(:song, event: invitation_event)
      invitation_event.save!
      invitation = create(:entry_invitation, customer: customer, event_for_invitation: invitation_event)
      sign_in customer
      withdraw!

      post customer_registration_path, params: {
        customer: { email: original_email, password: "password", password_confirmation: "password", name: "新しい私" }
      }
      new_account = Customer.find_by(email: original_email)

      expect(new_account).to be_present
      expect(new_account.id).not_to eq(customer.id)
      expect(new_account).not_to be_withdrawn
      expect(CommunityOwner.where(customer_id: new_account.id)).to be_empty
      expect(new_account.can_manage_community?(community)).to be(false)

      ActionMailer::Base.deliveries.clear
      SendEntryInvitationJob.perform_now(invitation.id)
      expect(ActionMailer::Base.deliveries.map(&:to).flatten).not_to include(original_email)
      expect(invitation.reload).to be_skipped
    end
  end

  describe "管理画面" do
    it "本人が退会したアカウントは「有効」に戻せない" do
      Customers::Withdrawal::Execute.call(customer)

      customer.reload.is_deleted = false

      expect(customer).not_to be_valid
      expect(customer.errors[:is_deleted]).to be_present
    end
  end
end
