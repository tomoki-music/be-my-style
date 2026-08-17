require 'rails_helper'

RSpec.describe "Business::Customers", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:withdrawn_customer) { create(:customer, is_deleted: true) }

  before { sign_in customer }

  describe "GET /business/customers/:id (show)" do
    it "現役ユーザーのプロフィールは表示されること" do
      get business_customer_path(other_customer)

      expect(response.status).to eq 200
      expect(response.body).to include(other_customer.name)
    end

    context "対象が退会済み(is_deleted: true)の場合" do
      it "プロフィール内容を表示せずリダイレクトされること" do
        get business_customer_path(withdrawn_customer)

        expect(response.status).to eq 302
      end

      it "本人を特定できる情報を含まない汎用メッセージであること" do
        get business_customer_path(withdrawn_customer)
        follow_redirect!

        expect(response.body).to include("このユーザーのプロフィールは表示できません。")
        expect(response.body).not_to include(withdrawn_customer.name)
      end
    end

    context "フォロー数・フォロワー数" do
      it "退会済みユーザーをフォローしていてもフォロー数に数えないこと" do
        customer.follow(other_customer.id)
        customer.follow(withdrawn_customer.id)

        expect(customer.followings.active.count).to eq 1
      end
    end
  end
end
