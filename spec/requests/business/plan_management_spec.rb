require "rails_helper"

# Business の契約・料金はトップではなくプロフィール編集の「契約プラン管理」で扱う。
RSpec.describe "Business の契約プラン管理への導線", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:customer) { create(:customer, domain_name: "business", onboarding_done: true) }

  def plan_section
    Nokogiri::HTML(response.body).at_css("#plan-management")
  end

  it "プラン不足で使えない機能の案内は契約プラン管理へ誘導する" do
    community = create(:community, owner: create(:customer), domain: business_domain)
    CommunityCustomer.create!(community: community, customer: customer)
    sign_in customer

    get business_community_path(community)

    cta = Nokogiri::HTML(response.body).at_css("a.menu-btn-locked")
    expect(cta.text.strip).to eq "coreでプロジェクトを始める"
    expect(cta["href"]).to eq edit_business_customer_path(customer, anchor: "plan-management")
  end

  it "free 会員の契約プラン管理には core / premium の登録を出し、light の新規登録は出さない" do
    sign_in customer

    get edit_business_customer_path(customer)

    expect(plan_section.at_css(%(a[href="#{business_checkout_path("core")}"]))).to be_present
    expect(plan_section.at_css(%(a[href="#{business_checkout_path("premium")}"]))).to be_present
    expect(plan_section.at_css(%(a[href="#{business_checkout_path("light")}"]))).to be_nil
    expect(plan_section.text).not_to include("lightを始める")
  end

  it "light 契約者には契約中の light を引き続き表示する" do
    create(:subscription, customer: customer, plan: "light")
    sign_in customer

    get edit_business_customer_path(customer)

    expect(customer.reload.plan).to eq "light"
    expect(plan_section.text.downcase).to include("light")
  end

  it "music 側の契約プラン管理では light の登録を引き続き出す" do
    music_customer = create(:customer)
    sign_in music_customer

    get edit_public_customer_path(music_customer)

    expect(response.body).to include("lightを始める").or include("lightを登録し直す").or include("Stripeでプラン変更・解約")
  end
end
