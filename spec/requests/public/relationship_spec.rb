require 'rails_helper'

RSpec.describe "relationshipsコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:withdrawn_customer) { create(:customer, is_deleted: true) }

  describe 'ログイン済み' do
    before { sign_in customer }

    describe "POST /public/customers/:customer_id/relationships (create)" do
      let(:referer_headers) { { "HTTP_REFERER" => public_communities_path } }

      it "有効ユーザーはフォローできること" do
        expect do
          post public_customer_relationships_path(other_customer.id), headers: referer_headers
        end.to change(Relationship, :count).by(1)
      end

      it "退会済みユーザーはフォローできないこと" do
        expect do
          post public_customer_relationships_path(withdrawn_customer.id), headers: referer_headers
        end.not_to change(Relationship, :count)
      end

      it "退会済みユーザーへのフォローは500エラーにならないこと" do
        post public_customer_relationships_path(withdrawn_customer.id), headers: referer_headers

        expect(response.status).not_to eq 500
      end
    end

    describe "GET /public/customers/:customer_id/followings, /followers" do
      it "退会済みユーザーをフォローしていてもエラーにならないこと" do
        customer.follow(withdrawn_customer.id)

        get public_customer_followings_path(customer.id)
        expect(response.status).not_to eq 500

        get public_customer_followers_path(customer.id)
        expect(response.status).not_to eq 500
      end
    end
  end
end
