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
    context "communityに参加(join)できる" do
      it 'コミュニティ参加人数が増える' do
        expect do
          get public_community_join_path(community)
        end.to change(community.customers, :count).by(1)
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
    context "community新規作成(create)が正しく処理され登録される" do
      it "コミュニティの作成が成功する" do
        expect do
          post public_communities_path, params: {
            community: {
              name: "MMM",
              introduction: "楽しいコミュニティです！",
            }
          }
        end.to change(Community, :count).by(1)
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
    context "community編集(update)が正しく処理され登録される" do
      it '記事を編集できること' do
        put public_community_path(community), params: {
          community: {
            name: "MMM埼玉",
            introduction: "自由なコミュニティです！",
          }
        }
        expect(community.reload.name).to eq 'MMM埼玉'
        expect(community.reload.introduction).to eq '自由なコミュニティです！'
      end
      it 'リクエストは302 Foundとなること（オーナーでない場合）' do
        sign_in other_customer
        put public_community_path(community), params: {
          community: {
            name: "MMM埼玉",
            introduction: "自由なコミュニティです！",
          }
        }
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
    context "communityjから退会(leave)できる" do
      before do
        get public_community_join_path(community)
      end
      it 'コミュニティ参加人数が減る' do
        expect do
          delete public_community_leave_path(community)
        end.to change(community.customers, :count).by(-1)
      end
    end
    context "communityからメール(new_mail)できる" do
      before do
        get public_community_new_mail_path(community)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "communityからメール送信(send_mail)のテスト" do
      before do
        community.customers << other_customer
        community_customers = community.customers
      end
      it "メールの作成と送信が成功する" do
        get public_community_send_mail_path(community), params: {
          mail_title: "メンバーの皆さんへ",
          mail_content: "どうぞ宜しくお願い致します！",
        }
        expect(response.body).to include("メンバーへの送信が完了しました!")
      end
      it "空欄があるとメールの作成と送信が失敗する（メールのバリデーション）" do
        get public_community_send_mail_path(community), params: {
          mail_title: "",
          mail_content: "",
        }
        expect(flash[:alert]).to eq("タイトル、本文は必須です。")
      end
    end
    context "加入申請一覧ページ(permits)のテスト" do
      before do
        get public_permits_path(community)
      end
      it 'コミュニティオーナーの場合：リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'コミュニティオーナーでない場合：リクエストは302 FOUNDとなること' do
        sign_in other_customer
        get public_permits_path(community)
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
    context "communityに参加(join)できない" do
      before do
        get public_community_join_path(community)
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
    context "community新規作成(create)ができない" do
      it "コミュニティの作成はされずページ遷移する" do
        post public_communities_path, params: {
          community: {
            name: "MMM",
            introduction: "楽しいコミュニティです！",
          }
        }
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
    context "communities編集は更新(update)されない" do
      before do
        put public_community_path(community), params: {
          community: {
            name: "MMM埼玉",
            introduction: "自由なコミュニティです！",
          }
        }
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
    context "communityからメール(new_mail)できない" do
      before do
        get public_community_new_mail_path(community)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "communityからメール送信(send_mail)できない" do
      before do
        community.customers << other_customer
        community_customers = community.customers
      end
      it "リクエストは302 Foundとなること" do
        get public_community_send_mail_path(community), params: {
          mail_title: "メンバーの皆さんへ",
          mail_content: "どうぞ宜しくお願い致します！",
        }
        expect(response.status).to eq 302
      end
    end
    context "加入申請一覧ページ(permits)表示に失敗" do
      before do
        get public_permits_path(community)
      end
      it 'リクエストは302 FOUNDとなること' do
        expect(response.status).to eq 302
      end
    end
  end
end
