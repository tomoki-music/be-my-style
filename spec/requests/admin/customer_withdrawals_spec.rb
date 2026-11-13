require "rails_helper"

# 管理画面の会員状態「退会」(会員編集 → 確認画面 → 確定)。確定は本人の退会と同じ Customers::Withdrawal::Execute を使う。
RSpec.describe "管理画面からの会員の退会", type: :request do
  include ActiveJob::TestHelper

  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:admin) { create(:admin) }
  # Admin::CustomersController は Customer のログインも必要(既存の挙動)。運営者自身の会員アカウント。
  let(:operator) { create(:customer, name: "運営の会員") }
  let(:password) { "password123" }
  let(:target) do
    create(:customer, name: "退会させる人", email: "target@example.com", password: password,
                      password_confirmation: password, introduction: "よろしくお願いします", confirm_mail: true,
                      onboarding_done: true)
  end
  let(:session_cookie_key) { Rails.application.config.session_options[:key] }

  def sign_in_as_admin
    sign_in operator
    sign_in admin
  end

  def confirm_withdrawal!(customer = target, confirmation: customer.id)
    post admin_customer_withdrawal_path(customer), params: { confirmation_customer_id: confirmation }
  end

  def expect_not_withdrawn(customer, name:, email:)
    customer.reload
    expect(customer.withdrawn_at).to be_nil
    expect(customer.is_deleted).to be(false)
    expect(customer.name).to eq(name)
    expect(customer.email).to eq(email)
  end

  describe "会員編集画面" do
    before { sign_in_as_admin }

    it "会員状態の欄に、退会は確認画面へ進むこと・ほかの欄は保存しないことを説明する" do
      get edit_admin_customer_path(target)

      expect(response).to have_http_status(:ok)
      help = Nokogiri::HTML(response.body).at_css("#customer-is-deleted-help").text
      expect(help).to include("確認画面に進みます")
      expect(help).to include("ほかの欄の変更は保存されません")
    end

    it "「退会」を選んで保存すると、ほかの欄の変更も含めて何も保存せずに確認画面へ進む" do
      target.create_member_profile!(admin_memo: "元のメモ")

      patch admin_customer_path(target), params: {
        customer: { name: "書き換えた名前", email: "changed@example.com", is_deleted: "true", is_owner: "community_owner",
                    member_profile_attributes: { id: target.member_profile.id, admin_memo: "書き換えたメモ" } }
      }

      expect(response).to redirect_to(new_admin_customer_withdrawal_path(target))
      expect_not_withdrawn(target, name: "退会させる人", email: "target@example.com")
      expect(target.is_owner).not_to eq("community_owner")
      expect(target.member_profile.reload.admin_memo).to eq("元のメモ")
    end

    it "通常の編集では退会の処理を行わない" do
      expect(Customers::Withdrawal::Execute).not_to receive(:call)

      patch admin_customer_path(target), params: { customer: { name: "新しい名前", is_deleted: "false" } }

      expect(response).to redirect_to(admin_homes_top_path)
      expect_not_withdrawn(target, name: "新しい名前", email: "target@example.com")
    end

    it "ほかの状態(管理者設定)の変更でも退会の処理を行わない" do
      expect(Customers::Withdrawal::Execute).not_to receive(:call)

      patch admin_customer_path(target), params: { customer: { is_owner: "manager", is_deleted: "false" } }

      expect(target.reload.is_owner).to eq("manager")
      expect(target.withdrawn_at).to be_nil
    end
  end

  describe "確認画面" do
    before { sign_in_as_admin }

    it "開いただけでは退会せず、対象と影響・戻ると確定のボタンを表示する" do
      get new_admin_customer_withdrawal_path(target)

      expect(response).to have_http_status(:ok)
      expect_not_withdrawn(target, name: "退会させる人", email: "target@example.com")

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("[data-withdrawal-target-id='#{target.id}']")).to be_present
      body = response.body
      expect(body).to include("退会させる人")
      expect(body).to include("target@example.com")
      expect(body).to include("退会済みユーザー")
      expect(body).to include("ログインできなくなります")
      expect(body).to include("新しく届かなくなります")
      expect(body).to include("退会完了のメールは送りません")
      expect(body).to include("共有履歴として残り")
      expect(body).to include("復元できません")
      expect(doc.at_css("a[href='#{edit_admin_customer_path(target)}']").text).to include("戻る")
      expect(doc.at_css("form[action='#{admin_customer_withdrawal_path(target)}'] input[type=submit]")["value"]).to eq("退会を確定する")
    end

    it "退会できない理由があれば、対象と対応方法を出し、確定ボタンを出さない" do
      create(:community, owner_id: target.id, name: "わたしのバンド部")

      get new_admin_customer_withdrawal_path(target)

      expect(response.body).to include("オーナーになっているコミュニティがあります")
      expect(response.body).to include("わたしのバンド部")
      expect(response.body).to include("管理者でもこの条件は省略できません")
      expect(response.body).not_to include("退会を確定する")
    end
  end

  describe "確定" do
    before { sign_in_as_admin }

    it "会員 ID を入力して確定すると、本人の退会と同じ処理で個人情報の削除・ログインの無効化を行う" do
      target.create_member_profile!(admin_memo: "メモ")
      ActionMailer::Base.deliveries.clear
      expect(Customers::Withdrawal::Execute).to receive(:call).with(target, include_legacy_deleted: false).and_call_original

      confirm_withdrawal!

      expect(response).to redirect_to(edit_admin_customer_path(target))
      target.reload
      expect(target.withdrawn_at).to be_present
      expect(target.is_deleted).to be(true)
      expect(target.name).to eq(Customer::WITHDRAWN_NAME)
      expect(target.email).to end_with("@#{WithdrawnMailInterceptor::DOMAIN}")
      expect(target.introduction).to be_nil
      expect(target.confirm_mail).to be(false)
      expect(target.member_profile).to be_nil
      expect(target.valid_password?(password)).to be(false)
      expect(target.active_for_authentication?).to be(false)
      # 退会者本人への完了メールなどは送らない。
      expect(ActionMailer::Base.deliveries).to be_empty

      follow_redirect!
      expect(response.body).to include("退会を確定しました")
      expect(response.body).to include("退会の手続きが済んでいます")
    end

    it "確認欄の会員 ID が空・違うときは退会しない(別の会員 ID を入れても、その会員も対象にならない)" do
      other = create(:customer, name: "別の人", email: "other@example.com")

      confirm_withdrawal!(confirmation: "")
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("確認欄に会員 ID")

      confirm_withdrawal!(confirmation: other.id)
      expect(response).to have_http_status(:unprocessable_entity)

      expect_not_withdrawn(target, name: "退会させる人", email: "target@example.com")
      expect_not_withdrawn(other, name: "別の人", email: "other@example.com")
    end

    it "退会できない理由があれば 422 で案内し、何も変えない(所有権の移譲やイベントの中止もしない)" do
      community = create(:community, owner_id: target.id)
      event = build(:event, customer: target, community: community, event_start_time: 10.days.from_now,
                            event_end_time: 10.days.from_now + 3.hours, event_entry_deadline: 5.days.from_now)
      event.songs << build(:song, event: event)
      event.save!

      confirm_withdrawal!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("退会を確定できない理由があります")
      expect(response.body).to include("主催している、終了していないイベントがあります")
      expect_not_withdrawn(target, name: "退会させる人", email: "target@example.com")
      expect(community.reload.owner_id).to eq(target.id)
      expect(Event.exists?(event.id)).to be(true)
    end

    it "管理者(システム管理者)の会員は退会できない" do
      target.update!(is_owner: :admin)

      confirm_withdrawal!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("管理者(システム管理者)の会員です")
      expect(target.reload.withdrawn_at).to be_nil
    end

    it "操作している運営者自身の会員アカウントは退会できない" do
      confirm_withdrawal!(operator)

      expect(response).to redirect_to(edit_admin_customer_path(operator))
      expect(operator.reload.withdrawn_at).to be_nil
      expect(operator.is_deleted).to be(false)
    end

    it "二重送信の2回目は何もせず、退会済みであることを案内する" do
      confirm_withdrawal!
      first_email = target.reload.email
      expect(Customers::Withdrawal::Execute).not_to receive(:call)

      confirm_withdrawal!

      expect(response).to redirect_to(edit_admin_customer_path(target))
      expect(flash[:alert]).to include("すでに退会の手続きが済んでいます")
      expect(target.reload.email).to eq(first_email)
    end

    it "確認画面を開いた後に別の操作で退会済みになっていた場合も、二重に処理しない" do
      # 別の運営者・本人が先に確定し、こちらの確定が認証・事前確認を通った後に Execute へ到達した状況。
      allow(Customers::Withdrawal::Execute).to receive(:call).and_wrap_original do |original, customer|
        original.call(Customer.find(customer.id))
        original.call(customer)
      end

      confirm_withdrawal!

      expect(response).to redirect_to(edit_admin_customer_path(target))
      expect(flash[:notice]).to include("すでに退会済み")
    end

    it "DB の更新に失敗したら、何も変えずに案内する" do
      allow_any_instance_of(Customers::Withdrawal::Execute).to receive(:anonymize_account!)
        .and_raise(ActiveRecord::StatementInvalid, "boom")
      follower = create(:customer)
      Relationship.create!(follower_id: follower.id, followed_id: target.id)

      confirm_withdrawal!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("会員の情報は変更していません")
      expect_not_withdrawn(target, name: "退会させる人", email: "target@example.com")
      expect(Relationship.where(followed_id: target.id)).to exist
    end

    it "ほかの会員との共有履歴(活動報告)や、ほかの会員のデータは残す" do
      activity = create(:activity, customer: target, title: "練習の記録")
      other = create(:customer, name: "ほかの会員")
      other_activity = create(:activity, customer: other)

      confirm_withdrawal!

      expect(activity.reload.title).to eq("練習の記録")
      expect(activity.customer_id).to eq(target.id)
      expect(other_activity.reload).to be_present
      expect(other.reload.name).to eq("ほかの会員")
    end

    it "旧方式で退会扱いになっている会員には、何も行わない(一括処理しない)" do
      legacy = create(:customer, name: "旧方式の人", email: "legacy@example.com")
      legacy.update_columns(is_deleted: true)

      confirm_withdrawal!

      legacy.reload
      expect(legacy.name).to eq("旧方式の人")
      expect(legacy.email).to eq("legacy@example.com")
      expect(legacy.withdrawn_at).to be_nil
    end
  end

  describe "退会後" do
    before { sign_in_as_admin }

    it "編集フォームを出さず、同じフォームの値を送っても削除・置き換えた情報を戻さない" do
      confirm_withdrawal!
      withdrawn_email = target.reload.email

      get edit_admin_customer_path(target)
      expect(response.body).to include("退会の手続きが済んでいます")
      expect(response.body).not_to include("customer[name]")

      patch admin_customer_path(target), params: {
        customer: { name: "退会させる人", email: "target@example.com", introduction: "よろしくお願いします", is_deleted: "false" }
      }

      expect(response).to redirect_to(edit_admin_customer_path(target))
      target.reload
      expect(target.name).to eq(Customer::WITHDRAWN_NAME)
      expect(target.email).to eq(withdrawn_email)
      expect(target.introduction).to be_nil
      expect(target.is_deleted).to be(true)
    end

    it "退会前に予約されていた通知は退会者へ届かず、ほかの会員への通知は届く" do
      other = create(:customer, confirm_mail: true)
      ActionMailer::Base.deliveries.clear
      CustomerMailer.with(ac_customer: other, ps_customer: target).create_follow_mail.deliver_later
      CustomerMailer.with(ac_customer: target, ps_customer: other).create_follow_mail.deliver_later

      confirm_withdrawal!
      perform_enqueued_jobs

      delivered = ActionMailer::Base.deliveries.flat_map { |mail| Array(mail.to) }
      expect(delivered).to eq([other.email])
    end
  end

  describe "退会後のログイン" do
    it "退会した会員のログインは、残っていたセッションも含めて使えない" do
      # 退会させる会員として別のブラウザでログインしていた状態を作り、そのセッション Cookie を保存する。
      target
      post customer_session_path, params: { customer: { email: "target@example.com", password: password, remember_me: "0" } }
      get public_notifications_path
      expect(response).to have_http_status(:ok)
      target_session = cookies[session_cookie_key]

      reset!
      sign_in_as_admin
      confirm_withdrawal!
      expect(target.reload.withdrawn_at).to be_present

      reset!
      cookies[session_cookie_key] = target_session
      get public_notifications_path
      expect(response).to redirect_to(new_customer_session_url)

      post customer_session_path, params: { customer: { email: "target@example.com", password: password } }
      get public_notifications_path
      expect(response).to redirect_to(new_customer_session_url)
    end
  end

  describe "旧方式の退会(is_deleted のみ)の会員" do
    let(:legacy) do
      create(:customer, name: "旧方式の人", email: "legacy@example.com", introduction: "残っている自己紹介")
    end

    before do
      legacy.update_columns(is_deleted: true)
      sign_in_as_admin
    end

    def expect_still_legacy_deleted
      legacy.reload
      expect(legacy.is_deleted).to be(true)
      expect(legacy.withdrawn_at).to be_nil
      expect(legacy.name).to eq("旧方式の人")
      expect(legacy.email).to eq("legacy@example.com")
      expect(legacy.introduction).to eq("残っている自己紹介")
    end

    it "編集画面で旧方式であることを説明し、退会処理へ進む専用のボタンを出す" do
      get edit_admin_customer_path(legacy)

      expect(response.body).to include("旧方式の退会(利用停止のみ)の会員です")
      link = Nokogiri::HTML(response.body).at_css("a[href='#{new_admin_customer_withdrawal_path(legacy)}']")
      expect(link.text.strip).to eq("個人情報の削除を伴う退会処理へ進む")
    end

    it "「退会」のまま保存しても、退会の処理(個人情報の削除)は起動せず、従来どおりの編集になる" do
      expect(Customers::Withdrawal::Execute).not_to receive(:call)

      patch admin_customer_path(legacy), params: { customer: { name: "旧方式の人(更新)", is_deleted: "true" } }

      expect(response).to redirect_to(admin_homes_top_path)
      legacy.reload
      expect(legacy.name).to eq("旧方式の人(更新)")
      expect(legacy.email).to eq("legacy@example.com")
      expect(legacy.is_deleted).to be(true)
      expect(legacy.withdrawn_at).to be_nil
    end

    it "確認画面は開いただけでは何も変えず、旧方式の会員であること・退会扱いのまま処理することを説明する" do
      get new_admin_customer_withdrawal_path(legacy)

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).at_css("[data-legacy-deleted]")).to be_present
      expect(response.body).to include("「有効」には戻さない")
      expect(response.body).to include("退会を確定する")
      expect_still_legacy_deleted
    end

    it "会員 ID を入力して確定すると、退会扱いのまま共通の退会処理で個人情報を削除する" do
      expect(Customers::Withdrawal::Execute).to receive(:call)
        .with(legacy, include_legacy_deleted: true).and_call_original

      confirm_withdrawal!(legacy)

      expect(response).to redirect_to(edit_admin_customer_path(legacy))
      legacy.reload
      expect(legacy.withdrawn_at).to be_present
      expect(legacy.is_deleted).to be(true)
      expect(legacy.name).to eq(Customer::WITHDRAWN_NAME)
      expect(legacy.email).to end_with("@#{WithdrawnMailInterceptor::DOMAIN}")
      expect(legacy.introduction).to be_nil

      get edit_admin_customer_path(legacy)
      expect(response.body).to include("退会の手続きが済んでいます")
    end

    it "確認欄の会員 ID が違うときは何も変えない" do
      confirm_withdrawal!(legacy, confirmation: target.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect_still_legacy_deleted
    end

    it "止める理由があれば、旧方式の退会状態のまま理由を表示する" do
      create(:community, owner_id: legacy.id, name: "旧方式の人のバンド")

      confirm_withdrawal!(legacy)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("オーナーになっているコミュニティがあります")
      expect_still_legacy_deleted
    end

    it "途中で失敗しても、旧方式の退会状態のまま案内する(「有効」に戻らない)" do
      allow_any_instance_of(Customers::Withdrawal::Execute).to receive(:anonymize_account!)
        .and_raise(ActiveRecord::StatementInvalid, "boom")

      confirm_withdrawal!(legacy)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("会員の情報は変更していません")
      expect_still_legacy_deleted
    end

    it "ほかの旧方式の会員には触れない(一括処理しない)" do
      other_legacy = create(:customer, name: "別の旧方式の人", email: "other-legacy@example.com")
      other_legacy.update_columns(is_deleted: true)

      confirm_withdrawal!(legacy)

      other_legacy.reload
      expect(other_legacy.name).to eq("別の旧方式の人")
      expect(other_legacy.email).to eq("other-legacy@example.com")
      expect(other_legacy.withdrawn_at).to be_nil
    end
  end

  describe "権限・不正なリクエスト" do
    it "管理者としてログインしていなければ、確認画面も確定も受け付けない" do
      sign_in operator

      get new_admin_customer_withdrawal_path(target)
      expect(response).to redirect_to(new_admin_session_url)

      confirm_withdrawal!
      expect(response).to redirect_to(new_admin_session_url)
      expect(target.reload.withdrawn_at).to be_nil
    end

    it "GET では退会しない(確定は POST のみ)" do
      sign_in_as_admin

      expect { get admin_customer_withdrawal_path(target) }.to raise_error(ActionController::RoutingError)
      expect(target.reload.withdrawn_at).to be_nil
    end

    it "CSRF トークンのない送信は受け付けない" do
      sign_in_as_admin
      ActionController::Base.allow_forgery_protection = true

      expect { confirm_withdrawal! }.to raise_error(ActionController::InvalidAuthenticityToken)
      expect(target.reload.withdrawn_at).to be_nil
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end

  describe "会員一覧の物理削除" do
    it "退会とは別の操作であることを、ボタン名と確認文で示す" do
      sign_in_as_admin
      target

      get admin_homes_top_path

      link = Nokogiri::HTML(response.body).at_css("a[href='#{purge_path(customer_id: target.id)}']")
      expect(link.text.strip).to eq("物理削除")
      expect(link["data-confirm"]).to include("元に戻せません")
      expect(link["data-confirm"]).to include("会員状態「退会」")
    end
  end
end
