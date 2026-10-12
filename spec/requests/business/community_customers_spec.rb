require 'rails_helper'

RSpec.describe "Business::CommunityCustomers", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer) }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:applicant) { create(:customer) }
  let!(:permit) { create(:permit, community: community, customer: applicant) }

  def approve(customer_id = applicant.id)
    post business_community_community_customers_path(community_id: community.id, customer_id: customer_id)
  end

  describe "POST /business/communities/:community_id/community_customers (create)" do
    context "承認できる人" do
      {
        "オーナー" => -> { owner },
        "管理権限を付与された CommunityOwner" => -> { create(:customer).tap { |c| CommunityOwner.create!(community: community, customer: c) } },
        "Customer の is_owner が admin" => -> { create(:customer, is_owner: :admin) }
      }.each do |label, actor|
        it "#{label}は申請者の参加を許可でき、申請は消える" do
          sign_in instance_exec(&actor)

          expect { approve }.to change(CommunityCustomer, :count).by(1)
          expect(community.customers).to include(applicant)
          expect(Permit.exists?(permit.id)).to eq false
          expect(flash[:notice]).to eq "コミュニティへ参加を許可しました"
        end
      end

      it "申請していない会員は参加させられない" do
        sign_in owner
        outsider = create(:customer)

        expect { approve(outsider.id) }.not_to change(CommunityCustomer, :count)
        expect(flash[:alert]).to eq "参加申請が見つかりません。"
      end

      context "申請者が退会済み(is_deleted: true)の場合" do
        before do
          applicant.update!(is_deleted: true)
          sign_in owner
        end

        it "CommunityCustomerが作成されないこと" do
          expect { approve }.not_to change(CommunityCustomer, :count)
        end

        it "500エラーにならず安全にリダイレクトされること" do
          approve

          expect(response.status).to eq 302
        end
      end
    end

    context "承認できない人" do
      let(:member) { create(:customer).tap { |c| CommunityCustomer.create!(community: community, customer: c) } }

      {
        "一般参加者" => -> { member },
        "非参加者" => -> { create(:customer) },
        "申請者本人" => -> { applicant }
      }.each do |label, actor|
        it "#{label}が直接リクエストしても参加させられない" do
          sign_in instance_exec(&actor)

          expect { approve }.not_to change(CommunityCustomer, :count)
          expect(response).to redirect_to(business_community_path(community))
          expect(flash[:alert]).to eq "参加申請を承認する権限がありません。"
          expect(Permit.exists?(permit.id)).to eq true
        end
      end
    end

    describe "対象コミュニティ以外の申請" do
      let(:other_owner) { create(:customer) }
      let(:other_community) { create(:community, owner: other_owner, domain: business_domain) }
      let(:other_applicant) { create(:customer) }
      let!(:other_permit) { create(:permit, community: other_community, customer: other_applicant) }

      before { sign_in owner }

      it "自分のコミュニティの URL に他コミュニティの申請者 ID を指定しても承認できない" do
        expect { approve(other_applicant.id) }.not_to change(CommunityCustomer, :count)
        expect(flash[:alert]).to eq "参加申請が見つかりません。"
        expect(Permit.exists?(other_permit.id)).to eq true
        expect(other_community.customers).not_to include(other_applicant)
      end

      it "管理していないコミュニティの申請は承認できない" do
        expect {
          post business_community_community_customers_path(community_id: other_community.id, customer_id: other_applicant.id)
        }.not_to change(CommunityCustomer, :count)
        expect(flash[:alert]).to eq "参加申請を承認する権限がありません。"
        expect(Permit.exists?(other_permit.id)).to eq true
      end

      it "同じ人が両方に申請していても、承認されるのは URL のコミュニティだけ" do
        create(:permit, community: other_community, customer: applicant)

        approve

        expect(community.customers).to include(applicant)
        expect(other_community.customers).not_to include(applicant)
        expect(other_community.permits.where(customer: applicant)).to exist
      end
    end

    it "Business 以外のコミュニティは Business 画面から承認できない" do
      music_community = create(:community, owner: owner)
      create(:permit, community: music_community, customer: applicant)
      sign_in owner

      expect {
        post business_community_community_customers_path(community_id: music_community.id, customer_id: applicant.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
