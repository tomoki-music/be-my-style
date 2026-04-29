require 'rails_helper'

RSpec.describe "Singing::Joins", type: :request do
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }
  let!(:music_domain)   { Domain.find_or_create_by!(name: "music") }

  # confirmed_at を設定することで Devise confirmable をクリアしてサインイン可能にする
  let(:singing_customer) do
    FactoryBot.create(:customer, domain_name: "singing", confirmed_at: Time.current)
  end
  let(:music_customer) do
    FactoryBot.create(:customer, domain_name: "music", confirmed_at: Time.current)
  end

  # =========================================================
  # /singing/sign_in 経由のリダイレクト挙動
  # =========================================================
  describe "POST /singing/sign_in のリダイレクト先" do
    context "singing_user? の場合" do
      it "singing_root_path へリダイレクトされる" do
        post singing_customer_session_path, params: {
          customer: { email: singing_customer.email, password: "password" }
        }
        expect(response).to redirect_to(singing_root_path)
      end
    end

    context "singing 未登録ユーザー（music ユーザー）の場合" do
      it "singing_join_path へリダイレクトされる" do
        post singing_customer_session_path, params: {
          customer: { email: music_customer.email, password: "password" }
        }
        expect(response).to redirect_to(singing_join_path)
      end
    end
  end

  # =========================================================
  # GET /singing/join
  # =========================================================
  describe "GET /singing/join" do
    context "未認証の場合" do
      it "singing専用ログイン画面へリダイレクトされる" do
        get singing_join_path
        expect(response).to redirect_to(new_singing_customer_session_path)
      end
    end

    context "認証済みの場合" do
      it "確認ページを 200 で表示する" do
        sign_in music_customer
        get singing_join_path
        expect(response).to have_http_status(:ok)
      end

      it "既存権限ありユーザーは singing_root_path へ戻る" do
        sign_in singing_customer

        get singing_join_path

        expect(response).to redirect_to(singing_root_path)
      end
    end
  end

  # =========================================================
  # POST /singing/join
  # =========================================================
  describe "POST /singing/join" do
    context "未認証の場合" do
      it "singing専用ログイン画面へリダイレクトされる" do
        post singing_join_path
        expect(response).to redirect_to(new_singing_customer_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in music_customer }

      it "singingドメインが付与される" do
        expect {
          post singing_join_path
        }.to change { music_customer.domains.reload.exists?(name: "singing") }.from(false).to(true)
      end

      it "singing_root_path へリダイレクトされる" do
        post singing_join_path
        expect(response).to redirect_to(singing_root_path)
      end

      it "2回POSTしてもCustomerDomainが重複しない" do
        post singing_join_path
        expect {
          post singing_join_path
        }.not_to change { CustomerDomain.where(customer: music_customer, domain: singing_domain).count }
      end
    end
  end

  # =========================================================
  # /customers/sign_in の既存挙動が変わっていないこと
  # =========================================================
  describe "POST /customers/sign_in の挙動は変わらない" do
    let(:music_customer_done) do
      FactoryBot.create(:customer,
        domain_name: "music",
        confirmed_at: Time.current,
        onboarding_done: true)
    end

    it "music ユーザーが /customers/sign_in からログインすると singing_join_path へは行かない" do
      post customer_session_path, params: {
        customer: { email: music_customer_done.email, password: "password" }
      }
      expect(response).not_to redirect_to(singing_join_path)
    end

    it "music ユーザーが /customers/sign_in からログインすると root_path へ遷移する" do
      post customer_session_path, params: {
        customer: { email: music_customer_done.email, password: "password" }
      }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /customers/sign_out" do
    it "singing配下からのログアウト後は singing 専用ログインへ戻る" do
      sign_in singing_customer

      delete destroy_customer_session_path, headers: { "HTTP_REFERER" => singing_root_path }

      expect(response).to redirect_to(new_singing_customer_session_path)
    end

    it "通常導線からのログアウト後は既存どおり public_homes_top_path へ戻る" do
      music_customer_done = FactoryBot.create(
        :customer,
        domain_name: "music",
        confirmed_at: Time.current,
        onboarding_done: true
      )
      sign_in music_customer_done

      delete destroy_customer_session_path, headers: { "HTTP_REFERER" => root_path }

      expect(response).to redirect_to(public_homes_top_path)
    end
  end
end
