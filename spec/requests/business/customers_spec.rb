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

  describe "プロフィール設定の音楽専用項目" do
    let(:part) { create(:part, name: "ギター") }
    let(:genre) { Genre.create!(name: "ジャズ") }
    let(:music_and_business) do
      create(:customer, domain_name: "music").tap do |c|
        CustomerDomain.create!(customer: c, domain: Domain.find_or_create_by!(name: "business"))
        c.parts << part
        c.genres << genre
      end
    end

    before { sign_in music_and_business }

    it "Business のプロフィール設定には音楽登録があってもパート・ジャンル欄を出さない" do
      get edit_business_customer_path(music_and_business)

      expect(response.body).not_to include("customer[part_ids][]", "customer[genre_ids][]")
      expect(response.body).not_to include("ギター", "ジャズ")
    end

    it "Business 側で保存しても音楽のパート・ジャンルは消えず、送られても変更しない" do
      other_part = create(:part, name: "ベース")

      patch business_customer_path(music_and_business), params: { customer: { name: "新しい名前", job: "デザイナー" } }
      expect(music_and_business.reload.parts).to eq [part]
      expect(music_and_business.genres).to eq [genre]
      expect(music_and_business.name).to eq "新しい名前"

      patch business_customer_path(music_and_business), params: { customer: { name: "新しい名前", part_ids: [other_part.id], genre_ids: [""] } }
      expect(music_and_business.reload.parts).to eq [part]
      expect(music_and_business.genres).to eq [genre]
    end
  end
end
