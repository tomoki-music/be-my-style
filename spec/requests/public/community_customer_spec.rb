require 'rails_helper'

RSpec.describe "community_customersコントローラーのテスト", type: :request do
  define_negated_matcher :not_change, :change

  # factory の owner_id は固定値のため、申請者と取り違えないようオーナーを明示する。
  let!(:owner) { create(:customer) }
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let!(:community) { create(:community, owner: owner) }
  let!(:chat_room) { create(:chat_room) }
  let!(:permit) { create(:permit, customer_id: other_customer.id, community_id: community.id) }
  let!(:chat_room_customer) { create(:chat_room_customer, customer_id: community.owner_id, chat_room_id: chat_room.id, community_id: community.id) }

  describe 'オーナーでログイン' do
    before do
      sign_in owner
    end
    context "コミュニティ加入申請(create)が正しく許可されメンバーが登録される" do
      it "加入申請の許可が成功する" do
        expect do
          post public_community_community_customers_path(community, permit_id: permit.id)
        end.to change(CommunityCustomer, :count).by(1)
        expect(permit.class.exists?(permit.id)).to eq false
      end
      it "加入申請の許可が成功すると、チャットルームにメンバーが１名追加される" do
        expect do
          post public_community_community_customers_path(community, permit_id: permit.id)
        end.to change(ChatRoomCustomer, :count).by(1)
      end
    end

    context "申請者が退会済み(is_deleted: true)の場合" do
      before do
        other_customer.update!(is_deleted: true)
      end

      it "加入を許可せずCommunityCustomerが作成されないこと" do
        expect do
          post public_community_community_customers_path(community, permit_id: permit.id)
        end.not_to change(CommunityCustomer, :count)
      end

      it "500エラーにならず安全にリダイレクトされること" do
        post public_community_community_customers_path(community, permit_id: permit.id)

        expect(response.status).to eq 302
      end
    end

    context "別コミュニティの申請IDを指定した場合" do
      let(:other_community) { create(:community, owner: owner) }
      let!(:other_permit) { create(:permit, customer_id: customer.id, community_id: other_community.id) }

      it "自分のコミュニティのURLからは承認できず、申請も残る" do
        expect do
          post public_community_community_customers_path(community, permit_id: other_permit.id)
        end.not_to change(CommunityCustomer, :count)

        expect(response).to redirect_to(public_permits_path(community))
        expect(flash[:alert]).to eq "参加申請が見つかりません。"
        expect(Permit.exists?(other_permit.id)).to eq true
      end
    end
  end

  describe 'オーナー以外でログイン' do
    [
      ["一般参加者", :member],
      ["申請中の本人", :applicant],
      ["非参加者", :outsider],
      ["他コミュニティのオーナー", :other_owner]
    ].each do |label, role|
      context label do
        let(:actor) do
          case role
          when :member
            customer.tap { |c| CommunityCustomer.create!(customer: c, community: community) }
          when :applicant
            other_customer
          when :other_owner
            create(:customer).tap { |c| create(:community, owner: c) }
          else
            create(:customer)
          end
        end

        before { sign_in actor }

        it "URLを直接送っても承認できず、参加者・チャット参加者・申請が変わらない" do
          expect do
            post public_community_community_customers_path(community, permit_id: permit.id)
          end.to not_change(CommunityCustomer, :count).and not_change(ChatRoomCustomer, :count)

          expect(response).to redirect_to(public_community_path(community))
          expect(flash[:alert]).to eq "参加申請を承認する権限がありません。"
          expect(Permit.exists?(permit.id)).to eq true
        end
      end
    end
  end

  describe '非ログイン' do
    context "コミュニティ加入申請(create)の許可に失敗する" do
      it "加入申請の許可が失敗し、参加者・チャット参加者・申請が変わらない" do
        expect do
          post public_community_community_customers_path(community, permit_id: permit.id)
        end.to not_change(CommunityCustomer, :count).and not_change(ChatRoomCustomer, :count)
        expect(response).to redirect_to(new_customer_session_path)
        expect(Permit.exists?(permit.id)).to eq true
      end
    end
  end
end
