require "rails_helper"

# NAKAMA の青いロゴ・アイコンは Business の画面だけに出し、音楽・歌声側の共通 favicon は変えないこと。
RSpec.describe "Business のロゴとアイコン", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }

  def head_links(html)
    html.css("head link[rel='icon'], head link[rel='shortcut icon'], head link[rel='apple-touch-icon']")
  end

  def expect_business_icons(html)
    links = head_links(html)
    expect(links.map { |link| [link["rel"], link["type"]] }).to contain_exactly(
      ["icon", "image/svg+xml"], ["icon", "image/png"], ["apple-touch-icon", "image/png"]
    )
    expect(links.map { |link| link["href"] }).to all(include("business/nakama-"))
    expect(html.to_s).not_to include("favicon.ico")
  end

  it "ログイン前のトップはヘッダーとフッターに横長ロゴ(SVG)を出し、Business のアイコンを使う" do
    get business_root_path

    html = Nokogiri::HTML(response.body)
    expect(html.css(".ba-lp-brand__logo").map { |img| img["src"] }).to all(include("business/nakama-logo"))
    expect(html.css(".ba-lp-brand__logo").size).to eq 2
    expect(html.css(".ba-lp-brand__logo").map { |img| img["alt"] }).to all(eq(""))
    expect_business_icons(html)
  end

  it "ログイン後は上部バー・左ナビに横長ロゴ、縮めた左ナビ用にシンボルを出し、Business のアイコンを使う" do
    sign_in create(:customer, domain_name: "business", onboarding_done: true)

    get business_root_path

    html = Nokogiri::HTML(response.body)
    expect(html.at_css(".ba-topbar .ba-brand__logo")["src"]).to include("business/nakama-logo")
    expect(html.at_css(".ba-sidenav .ba-brand__logo")["src"]).to include("business/nakama-logo")
    expect(html.at_css(".ba-sidenav .ba-brand__symbol")["src"]).to include("business/nakama-symbol")
    expect(html.at_css(".ba-brand")["aria-label"]).to eq "NAKAMA ホーム"
    expect_business_icons(html)
  end

  it "Business のログイン・新規登録・パスワード再設定は Business のアイコンを使う" do
    [new_business_customer_session_path, new_business_customer_registration_path, new_business_customer_password_path].each do |path|
      get path

      expect(response).to have_http_status(:ok)
      expect_business_icons(Nokogiri::HTML(response.body))
    end
  end

  it "音楽・歌声の画面は従来どおり共通の favicon だけを使う" do
    [root_path, new_customer_session_path, singing_root_path].each do |path|
      get path

      links = head_links(Nokogiri::HTML(response.body))
      expect(links.size).to eq 1
      expect(links.first["href"]).to include("favicon")
      expect(response.body).not_to include("business/nakama-")
    end
  end
end
