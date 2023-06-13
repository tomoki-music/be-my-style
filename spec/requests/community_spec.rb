require 'rails_helper'

RSpec.describe "communitiesコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:community) { create(:community) }

  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "community一覧ページが正しく表示される" do
      before do
        get public_communities_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "community詳細ページが正しく表示される" do
      before do
        get public_community_path(community)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "community編集ページが正しく表示される" do
      it 'リクエストは200 OKとなること（オーナーである場合）' do
        get edit_public_community_path(community)
        expect(response.status).to eq 200
      end
      it 'リクエストは302 Foundとなること（オーナーでない場合）' do
        sign_in other_customer
        get edit_public_community_path(community)
        expect(response.status).to eq 302
      end
    end
  end
  describe '非ログイン' do
    context "communities一覧ページへ遷移されない" do
      before do
        get public_communities_path
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "communities詳細ページへ遷移されない" do
      before do
        get public_community_path(community)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "customers編集ページへ遷移されない" do
      before do
        get edit_public_community_path(community)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
  end
end
