require 'rails_helper'

RSpec.describe "communitiesコントローラーのテスト", type: :request do
  let!(:customer) { create(:customer) }
  let!(:other_customer) { create(:customer) }
  let(:community) { create(:community) }
  let(:chat_room) { create(:chat_room) }
  let!(:permit) { create(:permit, customer_id: other_customer.id, community_id: community.id) }
  let!(:chat_room_customer) { create(:chat_room_customer, customer_id: other_customer.id, chat_room_id: chat_room.id, community_id: community.id) }

  describe 'ログイン済み' do
    before do
      customer.create_subscription!(status: "active", plan: "premium")
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

    context "community一覧ページ(index)のowner表示" do
      it "ownerが存在するCommunityの一覧で、オーナー名が表示されること" do
        owned_community = create(:community, owner: customer, name: "オーナーありコミュニティ")

        get public_communities_path

        expect(response.status).to eq 200
        expect(response.body).to include(customer.name)
        expect(response.body).to include(owned_community.name)
      end

      it "ownerがnil(owner_idが存在しないCustomerを指す)のCommunityが含まれていても200を返すこと" do
        orphaned = create(:community, name: "オーナー欠損コミュニティ")
        orphaned.update_column(:owner_id, 999_999)

        expect { get public_communities_path }.not_to raise_error
        expect(response.status).to eq 200
      end

      it "ownerがnilの場合に「オーナー情報なし」が表示されること" do
        orphaned = create(:community, name: "オーナー欠損コミュニティ2")
        orphaned.update_column(:owner_id, 999_999)

        get public_communities_path

        expect(response.body).to include("オーナー情報なし")
      end

      it "ownerがnilの場合にそのCustomer詳細リンクを生成しないこと(壊れたリンクを出さない)" do
        orphaned = create(:community, name: "オーナー欠損コミュニティ3")
        orphaned.update_column(:owner_id, 999_999)

        get public_communities_path

        doc = Nokogiri::HTML(response.body)
        card = doc.at_css("#community-#{orphaned.id}")
        expect(card.at_css(".community-owner-img a")).to be_nil
      end

      it "ownerがnilのCommunityが混在していても、通常のCommunityと同じく一覧に表示されること(除外されない)" do
        owned = create(:community, owner: customer, name: "件数確認オーナーありコミュニティ")
        orphaned = create(:community, name: "件数確認オーナー欠損コミュニティ")
        orphaned.update_column(:owner_id, 999_999)

        get public_communities_path

        expect(response.body).to include(owned.name)
        expect(response.body).to include(orphaned.name)
      end

      it "owner取得によるN+1が発生しないこと(コミュニティ件数に比例してクエリが増えない)" do
        4.times { |i| create(:community, owner: create(:customer, name: "owner#{i}")) }

        query_count = 0
        counter = ->(_name, _started, _finished, _unique_id, payload) {
          query_count += 1 if payload[:sql].to_s.include?("FROM `customers`")
        }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          get public_communities_path
        end

        expect(query_count).to be <= 2
      end
    end

    context "community一覧ページ(index)のジャンル・検索絞り込み" do
      it "ジャンルで絞り込んでも200を返し、該当コミュニティのみ表示されること" do
        genre = Genre.create!(name: "ロック")
        matched = create(:community, name: "ロックコミュニティ", owner: customer)
        CommunityGenre.create!(community: matched, genre: genre)
        unmatched = create(:community, name: "無関係コミュニティ", owner: customer)

        get public_communities_path, params: { genre_id: genre.id }

        expect(response.status).to eq 200
        expect(response.body).to include(matched.name)
        expect(response.body).not_to include(unmatched.name)
      end

      it "キーワード検索でも200を返すこと" do
        create(:community, name: "検索確認コミュニティ", owner: customer)

        get public_communities_path, params: { keyword: "検索確認" }

        expect(response.status).to eq 200
        expect(response.body).to include("検索確認コミュニティ")
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

    context "community詳細ページ(show)からイベント編集者管理UIが削除されていること" do
      let(:owner) { create(:customer) }
      let(:community) { create(:community, owner: owner) }
      let(:member) { create(:customer) }

      before do
        CommunityOwner.find_or_create_by!(customer: owner, community: community)
        CommunityCustomer.find_or_create_by!(customer: owner, community: community)
        CommunityCustomer.find_or_create_by!(customer: member, community: community)
        CommunityCustomer.find_or_create_by!(customer: customer, community: community)
      end

      it 'オーナーで閲覧しても「イベント編集者管理」が表示されないこと' do
        sign_in owner
        get public_community_path(community)

        expect(response.body).not_to include("イベント編集者管理")
        expect(response.body).not_to include("イベントを作成・編集できるメンバーを設定します。")
      end

      it '一般メンバーで閲覧しても「イベント編集者」が表示されないこと' do
        get public_community_path(community)

        expect(response.body).not_to include("イベント編集者")
      end

      it 'CommunityEventEditorレコードが残っていても一覧やフォームが表示されないこと' do
        CommunityEventEditor.create!(customer: member, community: community)
        sign_in owner

        get public_community_path(community)

        expect(response.body).not_to include("community-event-editors")
        expect(response.body).not_to include("解除")
      end

      it '「プロフィール画面へ」リンクは引き続き表示されること' do
        get public_community_path(community)

        expect(response.body).to include("プロフィール画面へ")
      end

      it 'メンバー一覧のページネーションが正しく機能すること(200 OK)' do
        get public_community_path(community, page: 1)

        expect(response.status).to eq 200
      end

      it 'パート絞り込みが正しく機能すること(200 OK)' do
        get public_community_path(community, part_id: create(:part).id)

        expect(response.status).to eq 200
      end
    end

    context "旧イベント編集者の追加・解除routesが削除されていること" do
      let(:owner) { create(:customer) }
      let(:community) { create(:community, owner: owner) }
      let(:member) { create(:customer) }

      before do
        CommunityOwner.find_or_create_by!(customer: owner, community: community)
        sign_in owner
      end

      it '旧追加(create)URLへ直接POSTしても404となり権限を付与できないこと' do
        expect do
          post "/communities/#{community.id}/community_event_editors", params: { customer_id: member.id }
        end.to raise_error(ActionController::RoutingError)

        expect(CommunityEventEditor.count).to eq 0
      end

      it '旧解除(destroy)URLへ直接DELETEしても404となり権限を解除する処理が実行されないこと' do
        community_event_editor = CommunityEventEditor.create!(customer: member, community: community)

        expect do
          delete "/communities/#{community.id}/community_event_editors/#{community_event_editor.id}"
        end.to raise_error(ActionController::RoutingError)

        expect(CommunityEventEditor.exists?(community_event_editor.id)).to eq true
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
      it "作成したコミュニティはPremium由来として扱われる" do
        post public_communities_path, params: {
          community: {
            name: "MMM",
            introduction: "楽しいコミュニティです！",
          }
        }

        expect(Community.order(:created_at).last.required_plan_for_event_creation).to eq("premium")
      end
      it "チャットルームの作成が成功する" do
        expect do
          post public_communities_path, params: {
            community: {
              name: "MMM",
              introduction: "楽しいコミュニティです！",
            }
          }
        end.to change(ChatRoom, :count).by(1)
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
    context "communityから退会(leave)できる" do
      before do
        sign_in other_customer
      end
      it 'コミュニティ参加人数が減る' do
        expect do
          delete public_community_leave_path(community)
        end.to change(community.customers, :count).by(-1)
      end
      it 'チャットルームの参加人数が減る' do
        expect do
          delete public_community_leave_path(community)
        end.to change(ChatRoomCustomer, :count).by(-1)
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
      it 'コミュニティオーナーの場合、リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'コミュニティオーナーでない場合、リクエストは302 FOUNDとなること' do
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
    context "community新規作成ページ(new)へ遷移されない" do
      before do
        get new_public_community_path
      end
      it 'リクエストは302 OKとなること' do
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
