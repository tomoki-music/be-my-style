require "rails_helper"

RSpec.describe "Business::Posts", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:free_customer) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:other) { create(:customer, domain_name: "business", onboarding_done: true) }

  def create_post(attrs = {})
    post business_posts_path, params: { post: { title: "近況", body: "はじめての投稿", category: "free_post", tag_list: "" }.merge(attrs) }
  end

  describe "Free プランでの通常投稿(コミュニティに紐づかない投稿)" do
    before { sign_in free_customer }

    it "お試し設定に関係なく投稿フォームを開いて投稿できる" do
      expect(free_customer.plan).to eq "free"
      expect(Community.where(plan_restrictions_waived: true)).to be_empty

      get new_business_post_path
      expect(response).to have_http_status(:ok)

      expect { create_post }.to change(Post, :count).by(1)
      expect(response).to redirect_to(business_posts_path)
    end

    # タイムライン(posts#timeline)は MySQL 専用関数(UNIX_TIMESTAMP)を使うため、SQLite のテストでは一覧で確認する。
    it "一覧・ヘッダー・トップに有料プランへの誘導を出さない" do
      get business_posts_path
      expect(response.body).to include(new_business_post_path)
      expect(response.body).not_to include("lightで投稿を始める")
      expect(response.body).not_to include("Lightプラン契約で解放")

      get business_root_path
      expect(response.body).not_to include("lightで投稿を開始")
      expect(response.body).not_to include(business_checkout_path("light"))
      expect(response.body).to include(business_posts_path)
    end
  end

  describe "投稿者本人以外の編集・削除" do
    let!(:target) { Post.create!(customer: other, title: "他人の投稿", body: "本文", category: "free_post") }

    before { sign_in free_customer }

    it "編集画面・更新・削除はできない" do
      get edit_business_post_path(target)
      expect(response).to redirect_to(business_post_path(target))

      patch business_post_path(target), params: { post: { body: "書き換え", tag_list: "" } }
      expect(target.reload.body).to eq "本文"

      expect { delete business_post_path(target) }.not_to change(Post, :count)
      expect(flash[:alert]).to eq "この投稿を編集・削除する権限がありません。"
    end

    it "投稿者本人は編集・削除できる" do
      sign_in other

      patch business_post_path(target), params: { post: { body: "更新しました", tag_list: "" } }
      expect(target.reload.body).to eq "更新しました"

      expect { delete business_post_path(target) }.to change(Post, :count).by(-1)
    end
  end

  describe "music 側のプラン条件" do
    it "変わらない" do
      expect(Customer::FEATURE_RULES.slice(
        :music_direct_chat, :music_community_chat, :music_activity_create,
        :music_event_create, :music_community_mail, :music_community_create
      )).to eq(
        music_direct_chat: %w[free light core premium],
        music_community_chat: %w[free light core premium],
        music_activity_create: %w[free light core premium],
        music_event_create: %w[core premium],
        music_community_mail: %w[premium],
        music_community_create: %w[premium]
      )
      expect(free_customer.has_feature?(:music_event_create)).to eq false
      expect(free_customer.has_feature?(:music_community_create)).to eq false
    end
  end
end
