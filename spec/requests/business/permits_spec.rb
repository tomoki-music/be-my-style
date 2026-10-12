require 'rails_helper'

RSpec.describe "Business::Permits", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer) }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:applicant) { create(:customer) }
  let!(:permit) { create(:permit, community: community, customer: applicant) }

  def reject_applicant
    delete business_community_permit_path(community, customer_id: applicant.id)
  end

  describe "DELETE /business/communities/:community_id/permit (他人の申請の拒否)" do
    {
      "オーナー" => -> { owner },
      "管理権限を付与された CommunityOwner" => -> { create(:customer).tap { |c| CommunityOwner.create!(community: community, customer: c) } },
      "Customer の is_owner が admin" => -> { create(:customer, is_owner: :admin) }
    }.each do |label, actor|
      it "#{label}は申請を拒否できる(参加はさせない)" do
        sign_in instance_exec(&actor)

        expect { reject_applicant }.to change(Permit, :count).by(-1)
        expect(community.customers).not_to include(applicant)
        expect(response).to redirect_to(business_community_path(community))
        expect(flash[:alert]).to eq "参加申請を拒否しました"
      end
    end

    {
      "一般参加者" => -> { create(:customer).tap { |c| CommunityCustomer.create!(community: community, customer: c) } },
      "非参加者" => -> { create(:customer) }
    }.each do |label, actor|
      it "#{label}が直接リクエストしても他人の申請は消えない" do
        sign_in instance_exec(&actor)

        expect { reject_applicant }.not_to change(Permit, :count)
        expect(flash[:alert]).to eq "参加申請を拒否する権限がありません。"
      end
    end
  end

  describe "対象コミュニティ以外の申請の拒否" do
    let(:other_community) { create(:community, owner: create(:customer), domain: business_domain) }
    let(:other_applicant) { create(:customer) }
    let!(:other_permit) { create(:permit, community: other_community, customer: other_applicant) }

    before { sign_in owner }

    it "自分のコミュニティの URL に他コミュニティの申請者 ID を指定しても消えない" do
      expect { delete business_community_permit_path(community, customer_id: other_applicant.id) }.not_to change(Permit, :count)
      expect(Permit.exists?(other_permit.id)).to eq true
    end

    it "管理していないコミュニティの申請は拒否できない" do
      expect { delete business_community_permit_path(other_community, customer_id: other_applicant.id) }.not_to change(Permit, :count)
      expect(flash[:alert]).to eq "参加申請を拒否する権限がありません。"
    end

    it "同じ人が両方に申請していても、拒否されるのは URL のコミュニティだけ" do
      create(:permit, community: other_community, customer: applicant)

      reject_applicant

      expect(community.permits.where(customer: applicant)).not_to exist
      expect(other_community.permits.where(customer: applicant)).to exist
    end
  end

  describe "DELETE /business/communities/:community_id/permit (本人の取り消し)" do
    it "申請者本人は自分の申請を取り消せる" do
      sign_in applicant

      expect { delete business_community_permit_path(community) }.to change(Permit, :count).by(-1)
      expect(flash[:alert]).to eq "コミュニティ参加申請をキャンセルしました"
    end

    it "customer_id に自分を指定しても本人の取り消しとして扱う" do
      sign_in applicant

      expect { delete business_community_permit_path(community, customer_id: applicant.id) }.to change(Permit, :count).by(-1)
      expect(flash[:alert]).to eq "コミュニティ参加申請をキャンセルしました"
    end
  end
end
