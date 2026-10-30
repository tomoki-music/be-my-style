require "rails_helper"

RSpec.describe "Business::Helps", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }

  let(:section_ids) { %w[help-about help-structure help-community help-project help-posting help-status help-operator help-faq] }

  def doc
    Nokogiri::HTML(response.body)
  end

  it "ログイン前でも開け、紹介ページと同じヘッダー・フッターで、目次から全セクションへ移動できる" do
    get business_help_path

    expect(response).to have_http_status(:ok)
    expect(doc.at_css("body")["class"]).to eq "ba-lp"
    expect(doc.at_css("h1").text).to eq "NAKAMAの使い方"
    toc = doc.css(".ba-help-toc a").map { |a| a["href"] }
    expect(toc).to eq section_ids.map { |id| "##{id}" }
    section_ids.each { |id| expect(doc.at_css("##{id}")).to be_present, id }
    expect(doc.at_css("#help-visibility")).to be_present
    expect(doc.at_css(%(a[href="#{new_business_customer_registration_path}"]))).to be_present
    expect(doc.at_css(%(header a[href="#{business_help_path}"]))).to be_present
  end

  it "ログイン前は会員データを読まない" do
    community = create(:community, name: "非公開の検証コミュニティ", domain: business_domain)
    Post.create!(customer: create(:customer), title: "非公開の検証投稿", body: "本文", category: "free_post")

    get business_help_path

    expect(response.body).not_to include(community.name)
    expect(response.body).not_to include("非公開の検証投稿")
  end

  it "ログイン後は Business の枠(左ナビ・下部メニュー)の中に出し、ナビの現在地は使い方" do
    customer = create(:customer, domain_name: "business", onboarding_done: true)
    sign_in customer

    get business_help_path

    expect(response).to have_http_status(:ok)
    expect(doc.at_css("body")["class"]).to eq "ba-body"
    expect(doc.at_css(%(.ba-sidenav a[href="#{business_help_path}"]))["aria-current"]).to eq "page"
    expect(doc.at_css(%(#baMenuSheet a[href="#{business_help_path}"]))).to be_present
    expect(doc.at_css(%(a[href="#{new_business_customer_registration_path}"]))).to be_nil
  end

  it "作成条件の説明が現在のプラン判定と一致する" do
    expect(Customer::FEATURE_RULES[:business_community_create]).to eq %w[premium]
    expect(Customer::FEATURE_RULES[:business_project_create]).to eq %w[core premium]
    expect(Customer::FEATURE_RULES[:business_post_create]).to include("free")
    expect(Community::PLAN_RESTRICTION_WAIVABLE_FEATURES).to include(:business_project_create)

    get business_help_path

    operator = doc.at_css("#help-operator").text
    expect(operator).to include("Premiumプラン")
    expect(operator).to include("Coreプラン以上の参加者")
    expect(operator).to include("無料お試し中のコミュニティでは、プランに関係なく参加者が作成できます。")
    expect(operator).to include("プロジェクトの管理者・コミュニティの運営者でも、ほかの人が書いた投稿を1件ずつ編集・削除することはできません。")
  end

  it "ログイン前トップに使い方への導線と、文字とアイコンの3ステップ・利用イメージの絵1枚がある" do
    get business_root_path

    expect(doc.css(%(a[href="#{business_help_path}"])).size).to be >= 3
    steps = doc.css(".ba-flow__step")
    expect(steps.map { |step| step.at_css(".ba-flow__title").text }).to eq %w[コミュニティに参加 プロジェクトで協力 スレッドで話す]
    steps.each do |step|
      expect(step.at_css(".ba-flow__icon i")).to be_present
      expect(step.at_css(".ba-flow__text").text).to be_present
      expect(step.at_css("img")).to be_nil
    end

    images = doc.css("img.ba-illust")
    expect(images.size).to eq 1
    expect(images.first["src"]).to include("business/illustrations/ribbon")
    expect(images.first["alt"]).to eq ""
    expect([images.first["width"], images.first["height"]]).to eq %w[1200 800]
  end

  it "使い方ページは3ステップを文字とアイコンで説明し、利用イメージの絵は繰り返さない" do
    get business_help_path

    expect(doc.css("#help-about .ba-flow__step").size).to eq 3
    expect(doc.css("img.ba-illust")).to be_empty
  end

  describe "ログイン後ホームの利用ガイド" do
    let(:customer) { create(:customer, domain_name: "business", onboarding_done: true) }

    before { sign_in customer }

    it "所属0件では、空状態に次の操作(番号付き)・コミュニティを探す・使い方を出し、下の利用ガイドは重ねない" do
      get business_root_path

      empty = doc.at_css("#my-communities .ba-empty--guide")
      expect(empty.at_css(".ba-empty__title").text).to eq "まずはコミュニティに参加しましょう"
      expect(empty.css(".ba-guide-steps li").size).to eq 3
      expect(empty.at_css(%(a[href="#{business_communities_path}"]))).to be_present
      expect(empty.at_css(%(a[href="#{business_help_path}"]))).to be_present
      img = empty.at_css("img.ba-illust")
      expect(img["alt"]).to eq ""
      expect(img["src"]).to include("business/illustrations/ribbon-small")
      expect([img["width"], img["height"]]).to eq %w[480 320]
      expect(doc.at_css(".ba-home-guide")).to be_nil
      expect(doc.at_css(".ba-lp-hero, .ba-flow")).to be_nil
    end

    it "所属がある場合は、一覧の後ろに小さな利用ガイドと使い方への導線を出す" do
      community = create(:community, domain: business_domain)
      CommunityCustomer.create!(community: community, customer: customer)

      get business_root_path

      sections = doc.css(".ba-home > section, .ba-home > aside").map { |node| node["id"] || node["class"] }
      expect(sections).to eq ["my-communities", "my-projects", "ba-home-guide"]
      expect(doc.at_css(%(.ba-home-guide a[href="#{business_help_path}"]))).to be_present
      expect(doc.at_css(".ba-home-guide img.ba-illust")["alt"]).to eq ""
      expect(doc.at_css("#my-communities .ba-empty--guide")).to be_nil
    end
  end
end
