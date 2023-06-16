require 'rails_helper'

RSpec.describe "communitiesコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let!(:community) { create(:community) }

  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "community一覧ページ(index)が正しく表示される" do
      before do
        get public_communities_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "community詳細ページ(show)が正しく表示される" do
      before do
        get public_community_path(community)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "community新規作成ページ(new)が正しく表示される" do
      before do
        get new_public_community_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "community編集ページ(edit)が正しく表示される" do
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
    context "communityページを正しく削除(destroy)できる" do
      it '正しく削除できる（オーナーである場合）' do
        expect do
          delete public_community_path(community)
        end.to change(Community, :count).by(-1)
      end
      it 'リクエストは302 Foundとなること（オーナーでない場合）' do
        sign_in other_customer
        delete public_community_path(community)
        expect(response.status).to eq 302
      end
    end
  end
  describe '非ログイン' do
    context "communities一覧ページ(index)へ遷移されない" do
      before do
        get public_communities_path
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "communities詳細ページ(show)へ遷移されない" do
      before do
        get public_community_path(community)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "community新規作成ページ(new)へ遷移されない" do
      before do
        get new_public_community_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 302
      end
    end
    context "communities編集ページ(edit)へ遷移されない" do
      before do
        get edit_public_community_path(community)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "communities削除(destroy)できない" do
      before do
        delete public_community_path(community)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
  end
end
