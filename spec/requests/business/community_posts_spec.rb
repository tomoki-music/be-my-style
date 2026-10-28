require "rails_helper"

RSpec.describe "Business::CommunityPosts", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:free_member) { create(:customer, domain_name: "business") }

  before do
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: free_member, community: community)
  end

  def post_to(target, body)
    post business_community_community_posts_path(target), params: { community_post: { body: body } }
  end

  context "Free プランの参加者(お試し OFF)" do
    before { sign_in free_member }

    it "タイムラインに投稿できる" do
      expect(free_member.plan).to eq "free"
      expect(community.plan_restrictions_waived).to eq false

      expect { post_to(community, "はじめまして") }.to change(CommunityPost, :count).by(1)
      expect(response).to redirect_to(business_community_path(community))
    end

    it "タイムラインの閲覧と投稿フォームが表示され、有料プラン誘導は出ない" do
      CommunityPost.create!(community: community, customer: owner, body: "オーナーの投稿です")

      get business_community_path(community)

      expect(response.body).to include("オーナーの投稿です")
      expect(response.body).to include("投稿する...")
      expect(response.body).not_to include("lightプラン以上で開放")
    end
  end

  context "非参加者" do
    let(:outsider) { create(:customer, domain_name: "business") }

    before { sign_in outsider }

    it "Free でも有料プランでも投稿できない" do
      expect { post_to(community, "割り込み") }.not_to change(CommunityPost, :count)

      create(:subscription, customer: outsider, plan: "premium")
      expect { post_to(community, "割り込み") }.not_to change(CommunityPost, :count)
      expect(flash[:alert]).to eq "コミュニティに参加すると投稿できます。"
    end

    it "投稿フォームも本文も表示されず、参加案内が表示される" do
      CommunityPost.create!(community: community, customer: owner, body: "参加者だけが読める投稿")

      get business_community_path(community)

      expect(response.body).not_to include("参加者だけが読める投稿")
      expect(response.body).not_to include("投稿する...")
      expect(response.body).not_to include("business-stamp-picker")
      expect(response.body).to include("コミュニティの参加者のみ閲覧できます")
    end
  end

  context "他のコミュニティの参加者" do
    let(:other_community) { create(:community, owner: owner, domain: business_domain) }
    let(:other_member) { create(:customer, domain_name: "business") }

    before do
      CommunityCustomer.find_or_create_by!(customer: other_member, community: other_community)
      sign_in other_member
    end

    it "参加していないコミュニティには投稿できない" do
      expect { post_to(community, "越境投稿") }.not_to change(CommunityPost, :count)
    end
  end

  context "Business 以外のドメインのコミュニティ" do
    let(:music_community) { create(:community, owner: owner) }

    before do
      CommunityCustomer.find_or_create_by!(customer: free_member, community: music_community)
      sign_in free_member
    end

    it "Business 画面からは投稿できない" do
      expect {
        expect { post_to(music_community, "music へ") }.to raise_error(ActiveRecord::RecordNotFound)
      }.not_to change(CommunityPost, :count)
    end
  end
end
