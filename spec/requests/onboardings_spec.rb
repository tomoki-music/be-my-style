require 'rails_helper'

RSpec.describe "Onboardings - オンボーディング活動報告例外", type: :request do
  let(:activity_params) do
    {
      activity: {
        title: "はじめての活動報告",
        introduction: "オンボーディングテスト",
        keep: "継続できたこと",
        problem: "課題",
        try: "次にやること",
      }
    }
  end

  let(:post_params) do
    {
      post: {
        title: "はじめての投稿",
        body: "オンボーディングテスト投稿",
        category: "free_post",
      }
    }
  end

  # ──────────────────────────────────────────────
  # 1. music Free ユーザー: オンボーディング中は活動報告を1回作成できる
  # ──────────────────────────────────────────────
  describe "music Free ユーザーのオンボーディング活動報告" do
    let!(:music_customer) { create(:customer, domain_name: "music", onboarding_done: false, confirmed_at: Time.current) }

    before { sign_in music_customer }

    context "step3 を経由してから活動報告を作成する場合" do
      before { get onboarding_step3_path }

      it "Activity が1件増える" do
        expect {
          post public_activities_path, params: activity_params
        }.to change(Activity, :count).by(1)
      end

      it "作成成功後に onboarding_done が true になる" do
        post public_activities_path, params: activity_params
        expect(music_customer.reload.onboarding_done).to be true
      end

      it "作成成功後に public_activities_path へリダイレクトされる" do
        post public_activities_path, params: activity_params
        expect(response).to redirect_to(public_activities_path)
      end
    end

    context "step3 を経由せず直接 /activities/new にアクセスした場合（Free ユーザーは常時投稿可能）" do
      it "new ページへのアクセスが200 OKになること" do
        get new_public_activity_path
        expect(response.status).to eq 200
      end

      it "POST すると Activity が増えること" do
        expect {
          post public_activities_path, params: activity_params
        }.to change(Activity, :count).by(1)
      end
    end
  end

  # ──────────────────────────────────────────────
  # 2. business Free ユーザー: オンボーディング中は投稿を1回作成できる
  # ──────────────────────────────────────────────
  describe "business Free ユーザーのオンボーディング投稿" do
    let!(:business_customer) { create(:customer, domain_name: "business", onboarding_done: false, confirmed_at: Time.current) }

    before { sign_in business_customer }

    context "step3 を経由してから投稿を作成する場合" do
      before { get onboarding_step3_path }

      it "Post が1件増える" do
        expect {
          post business_posts_path, params: post_params
        }.to change(Post, :count).by(1)
      end

      it "作成成功後に onboarding_done が true になる" do
        post business_posts_path, params: post_params
        expect(business_customer.reload.onboarding_done).to be true
      end

      it "作成成功後に business_posts_path へリダイレクトされる" do
        post business_posts_path, params: post_params
        expect(response).to redirect_to(business_posts_path)
      end
    end

    context "step3 を経由せず直接 /business/posts/new にアクセスした場合（セッションフラグなし）" do
      it "POST しても Post が増えない" do
        expect {
          post business_posts_path, params: post_params
        }.not_to change(Post, :count)
      end
    end
  end

  # ──────────────────────────────────────────────
  # 3. オンボーディング完了済み music Free ユーザーは通常投稿できる（Free に投稿権あり）
  # ──────────────────────────────────────────────
  describe "onboarding_done 済みの music Free ユーザー" do
    let!(:done_customer) { create(:customer, domain_name: "music", onboarding_done: true, confirmed_at: Time.current) }

    before { sign_in done_customer }

    it "new ページへのアクセスが200 OKになること" do
      get new_public_activity_path
      expect(response.status).to eq 200
    end

    it "POST すると Activity が増えること" do
      expect {
        post public_activities_path, params: activity_params
      }.to change(Activity, :count).by(1)
    end
  end

  # ──────────────────────────────────────────────
  # 4. LIGHT 以上のユーザーは通常どおり活動報告できる
  # ──────────────────────────────────────────────
  describe "music LIGHT ユーザーの通常活動報告" do
    let!(:light_customer) { create(:customer, domain_name: "music", onboarding_done: true, confirmed_at: Time.current) }

    before do
      light_customer.build_subscription(status: "active", plan: "light").save!
      sign_in light_customer
    end

    it "step3 経由なしでも Activity を作成できる" do
      expect {
        post public_activities_path, params: activity_params
      }.to change(Activity, :count).by(1)
    end
  end

  # ──────────────────────────────────────────────
  # 5. learning / singing ユーザーには影響がない
  # ──────────────────────────────────────────────
  describe "learning ユーザーへの影響なし" do
    let!(:learning_customer) { create(:customer, domain_name: "learning", onboarding_done: false, confirmed_at: Time.current) }

    before do
      sign_in learning_customer
      get onboarding_step3_path
    end

    it "step3 を経由しても music 活動報告はブロックされる" do
      get new_public_activity_path
      # learning ユーザーは music ドメイン未登録のため music プラットフォームへのアクセス自体がリダイレクトされる
      expect(response.status).to eq 302
    end
  end

  describe "singing ユーザーへの影響なし" do
    let!(:singing_customer) { create(:customer, domain_name: "singing", onboarding_done: false, confirmed_at: Time.current) }

    before do
      sign_in singing_customer
      get onboarding_step3_path
    end

    it "step3 を経由しても music 活動報告はブロックされる" do
      get new_public_activity_path
      expect(response.status).to eq 302
    end
  end
end
