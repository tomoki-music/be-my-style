require 'rails_helper'

RSpec.describe "Business::Relationships", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:withdrawn_customer) { create(:customer, is_deleted: true) }

  before { sign_in customer }

  describe "POST /business/customers/:customer_id/relationships (create)" do
    it "有効ユーザーはフォローできること" do
      expect do
        post business_customer_relationships_path(other_customer.id)
      end.to change(Relationship, :count).by(1)
    end

    it "退会済みユーザーはフォローできないこと" do
      expect do
        post business_customer_relationships_path(withdrawn_customer.id)
      end.not_to change(Relationship, :count)
    end

    it "退会済みユーザーへのフォローは500エラーにならないこと" do
      post business_customer_relationships_path(withdrawn_customer.id)

      expect(response.status).not_to eq 500
    end
  end
end
