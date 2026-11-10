require "rails_helper"

# プロジェクト詳細の概要の折りたたみ(最初は3行まで)と、限定公開の一覧・詳細の見え方を実ブラウザで確認する。データはすべて架空。
RSpec.describe "Business プロジェクト概要の折りたたみと限定公開", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true, name: "青山 葵") }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "地域企画ラボ", introduction: "地域の企画好きの集まりです。") }
  let(:long_description) do
    "商店街のお店を取材して、魅力を伝える記事をつくります。\n" \
      "毎月2本の記事を目標に、取材・撮影・執筆を分担します。\n" \
      "3行目：初めての人も歓迎です。\n" \
      "4行目：取材先はみんなで相談して決めます。\n\n" \
      "## 募集したい人\n- 写真が好きな人\n- 文章を書くのが好きな人\n\n最後の行：月1回オンラインで集まります。"
  end
  let(:long_project) { Project.create!(community: community, customer: owner, title: "商店街の魅力発信", description: long_description) }
  let(:short_project) { Project.create!(community: community, customer: owner, title: "短い企画", description: "1行だけの概要です。") }

  before { CommunityCustomer.create!(community: community, customer: owner) }

  def set_viewport(width, height = 900)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: width < 600
    )
  end

  def sign_in_as(target)
    visit new_business_customer_session_path
    fill_in "customer_email", with: target.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_current_path(business_root_path, wait: 10)
  end

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  def shot(name, focus: nil, block: "start")
    FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
    page.execute_script("document.querySelector(#{focus.to_json}).scrollIntoView({ block: #{block.to_json} })") if focus
    page.save_screenshot(Rails.root.join("tmp/screenshots/#{name}.png").to_s)
  end

  # 概要の表示中の行数(高さ ÷ 行の高さ)。
  def visible_lines
    page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector('#project-about-body');
        var lineHeight = parseFloat(getComputedStyle(el).lineHeight);
        return Math.round(el.getBoundingClientRect().height / lineHeight);
      })()
    JS
  end

  def about_text_visible?(text)
    page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector('#project-about-body');
        var box = el.getBoundingClientRect();
        var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
        while (walker.nextNode()) {
          if (walker.currentNode.textContent.indexOf(#{text.to_json}) === -1) continue;
          var range = document.createRange();
          range.selectNodeContents(walker.currentNode);
          var r = range.getBoundingClientRect();
          return r.height > 0 && r.bottom <= box.bottom + 1;
        }
        return false;
      })()
    JS
  end

  [375, 1280].each do |width|
    it "幅#{width}px: 長い概要は3行まで表示し「もっと見る」で全文(改行を含む)、「閉じる」で3行に戻る" do
      sign_in_as(owner)
      set_viewport(width)
      visit business_project_path(long_project)

      toggle = find("[data-collapsible-toggle]", text: "もっと見る")
      expect(toggle["aria-expanded"]).to eq "false"
      expect(visible_lines).to eq 3
      expect(about_text_visible?("商店街のお店を取材して")).to be true
      expect(about_text_visible?("最後の行：月1回オンラインで集まります。")).to be false
      expect(horizontal_overflow).to be <= 0
      shot("project_about_collapsed_#{width}", focus: "#about")

      toggle.click
      expect(page).to have_css("[data-collapsible-toggle][aria-expanded='true']", text: "閉じる")
      expect(visible_lines).to be > 3
      %w[毎月2本の記事を目標に 3行目：初めての人も歓迎です。 4行目：取材先はみんなで相談して決めます。 写真が好きな人 最後の行：月1回オンラインで集まります。].each do |text|
        expect(about_text_visible?(text)).to be(true), text
      end
      # 改行(hard_wrap の <br>)で行が分かれている。
      expect(page.evaluate_script("document.querySelectorAll('#project-about-body br').length")).to be >= 3
      shot("project_about_expanded_#{width}", focus: "#about")

      find("[data-collapsible-toggle]", text: "閉じる").click
      expect(page).to have_css("[data-collapsible-toggle][aria-expanded='false']", text: "もっと見る")
      expect(visible_lines).to eq 3
      expect(about_text_visible?("最後の行：月1回オンラインで集まります。")).to be false
    end

    it "幅#{width}px: 3行に収まる短い概要には「もっと見る」を出さない" do
      sign_in_as(owner)
      set_viewport(width)
      visit business_project_path(short_project)

      expect(page).to have_css("#project-about-body", text: "1行だけの概要です。")
      expect(page).to have_no_css("[data-collapsible-toggle]", visible: :visible)
      expect(page).to have_no_text("もっと見る")
      expect(horizontal_overflow).to be <= 0
    end
  end

  it "限定公開のプロジェクトは一覧に出ず、URLからは限定公開のしるし付きで開け、編集画面から通常公開に戻せる" do
    long_project
    hidden = Project.create!(community: community, customer: owner, title: "限定の企画", description: "URLだけで共有します。", visibility: :unlisted)
    sign_in_as(owner)
    set_viewport(375, 812)

    visit business_community_path(community)
    within("#projects") do
      expect(page).to have_text("商店街の魅力発信")
      expect(page).to have_no_text("限定の企画")
    end
    shot("unlisted_community_projects_375", focus: "#projects")

    visit business_projects_path
    expect(page).to have_text("商店街の魅力発信")
    expect(page).to have_no_text("限定の企画")
    shot("unlisted_projects_index_375")

    visit business_project_path(hidden)
    expect(page).to have_css(".ba-status--unlisted", text: "限定公開")
    expect(horizontal_overflow).to be <= 0
    shot("unlisted_project_show_375")

    visit edit_business_project_path(hidden)
    expect(page).to have_select("project_visibility", selected: "限定公開")
    expect(page).to have_text("一覧・検索には表示されません。URLからの閲覧には既存の閲覧条件が適用されます")
    shot("unlisted_project_edit_375", focus: "#project_visibility", block: "center")
    select "通常公開", from: "project_visibility"
    click_button "保存する"

    expect(page).to have_current_path(business_project_path(hidden))
    expect(page).to have_no_css(".ba-status--unlisted")
    visit business_projects_path
    expect(page).to have_text("限定の企画")
  end
end
