require "rails_helper"

# 招待用URLのコピーと、テーマ入り画面の表示を実ブラウザで確認する。データはすべて架空。
RSpec.describe "Business 招待用URLのコピーとテーマ表示", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true, name: "青山 葵") }
  let(:community) do
    create(:community, owner: owner, domain: business_domain, name: "地域企画ラボ",
                       introduction: "地域の小さなお店と、企画が好きな人が集まるコミュニティです。")
  end
  let(:project) do
    Project.create!(community: community, customer: owner, title: "商店街の魅力発信",
                    theme: "地域のお店の魅力発信", description: "お店の取材記事を月に2本つくります。")
  end

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

  def shot(name)
    FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
    height = page.evaluate_script("Math.ceil(document.documentElement.scrollHeight)")
    width = page.evaluate_script("window.innerWidth")
    set_viewport(width, [height, 900].max)
    page.evaluate_async_script(<<~JS)
      var done = arguments[arguments.length - 1];
      document.querySelectorAll("img").forEach(function (img) { img.loading = "eager"; });
      var decoded = Promise.all(Array.from(document.images).map(function (img) { return img.decode().catch(function () {}); }));
      Promise.race([decoded, new Promise(function (resolve) { setTimeout(resolve, 3000); })])
        .then(function () { requestAnimationFrame(function () { requestAnimationFrame(done); }); });
    JS
    page.save_screenshot(Rails.root.join("tmp/screenshots/#{name}.png").to_s)
    set_viewport(width)
  end

  def grant_clipboard!
    page.driver.browser.execute_cdp(
      "Browser.grantPermissions",
      origin: page.server_url, permissions: %w[clipboardReadWrite clipboardSanitizedWrite]
    )
  end

  def share_url
    find("[data-share-url]").value
  end

  def selection_covers_url?
    page.evaluate_script(<<~JS)
      (function () {
        var input = document.querySelector('[data-share-url]');
        return document.activeElement === input && input.selectionStart === 0 && input.selectionEnd === input.value.length;
      })()
    JS
  end

  it "「URLをコピー」でクリップボードへ書き込み、読み上げ用の欄に結果を出す。参加・申請は起きない" do
    sign_in_as(owner)
    set_viewport(375, 812)
    visit business_community_path(community)
    grant_clipboard!

    button = find("[data-share-copy]", text: "URLをコピー")
    expect do
      button.click
      expect(page).to have_css(".ba-share__status[role='status']", text: "URLをコピーしました")
    end.not_to change { [Permit.count, CommunityCustomer.count, ProjectJoinRequest.count, ProjectMember.count] }

    copied = page.evaluate_async_script("var done = arguments[0]; navigator.clipboard.readText().then(done, function (e) { done('ERR ' + e); });")
    expect(copied).to eq share_url
    expect(copied).to eq "http://localhost:3000/business/communities/#{community.id}"
  end

  it "キーボード(Tab で移動して Enter)でもコピーできる" do
    sign_in_as(owner)
    set_viewport(1280)
    visit business_project_path(project)
    grant_clipboard!

    page.execute_script("document.querySelector('[data-share-url]').focus()")
    page.send_keys(:tab)
    expect(page.evaluate_script("document.activeElement.hasAttribute('data-share-copy')")).to be true
    expect(page.evaluate_script("getComputedStyle(document.activeElement).boxShadow")).not_to eq "none"
    page.send_keys(:enter)
    expect(page).to have_css(".ba-share__status", text: "URLをコピーしました")
  end

  it "コピーに失敗したときは、URL欄を全選択して手動コピーを案内する" do
    sign_in_as(owner)
    visit business_community_path(community)
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: function () { return Promise.reject(new Error('denied')); } } });
      document.execCommand = function () { return false; };
    JS

    find("[data-share-copy]").click

    expect(page).to have_css(".ba-share__status.is-error", text: "コピーできませんでした。選択されたURLを長押し")
    expect(selection_covers_url?).to be true
  end

  it "Clipboard API が無い環境では、古いコピー命令で代わりにコピーする" do
    sign_in_as(owner)
    visit business_community_path(community)
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'clipboard', { configurable: true, value: undefined });
      window.__copied = null;
      document.execCommand = function (name) { window.__copied = window.getSelection().toString() || document.activeElement.value.substring(document.activeElement.selectionStart, document.activeElement.selectionEnd); return name === 'copy'; };
    JS

    find("[data-share-copy]").click

    expect(page).to have_css(".ba-share__status", text: "URLをコピーしました")
    expect(page.evaluate_script("window.__copied")).to eq share_url
  end

  it "URL欄を押すと全体が選ばれ、読み取り専用なのでスマホの下部ナビは隠れない" do
    sign_in_as(owner)
    set_viewport(375, 812)
    visit business_project_path(project)

    find("[data-share-url]").click
    expect(page).to have_css("[data-share-url]:focus")
    expect(selection_covers_url?).to be true
    expect(page).to have_no_css("body.ba-is-typing")
  end

  [320, 375, 768, 1280].each do |width|
    it "幅#{width}px: コミュニティ・プロジェクトの通常画面とプロジェクトの編集画面が横にはみ出さない" do
      sign_in_as(owner)
      set_viewport(width)

      visit business_community_path(community)
      expect(page).to have_css(".ba-share [data-share-copy]", visible: :visible)
      expect(horizontal_overflow).to be <= 0
      shot("share_community_#{width}")

      visit business_project_path(project)
      expect(page).to have_css(".ba-theme__text", text: "地域のお店の魅力発信")
      expect(page).to have_no_text("締切")
      expect(page).to have_no_text("目標")
      expect(horizontal_overflow).to be <= 0
      # コピーのボタンは押しやすい大きさ(44px 以上)で、URL欄と重ならない。
      sizes = page.evaluate_script(<<~JS)
        (function () {
          var b = document.querySelector('[data-share-copy]').getBoundingClientRect();
          var i = document.querySelector('[data-share-url]').getBoundingClientRect();
          var overlap = !(b.right <= i.left || b.left >= i.right || b.bottom <= i.top || b.top >= i.bottom);
          return [b.height, overlap];
        })()
      JS
      expect(sizes[0]).to be >= 44
      expect(sizes[1]).to be false
      shot("share_project_#{width}")

      visit edit_business_project_path(project)
      expect(page).to have_field("project_theme", with: "地域のお店の魅力発信")
      expect(page).to have_no_field("project_goal")
      expect(page).to have_no_field("project_deadline")
      expect(horizontal_overflow).to be <= 0
      shot("project_edit_#{width}") if [375, 1280].include?(width)
    end
  end

  it "テーマが長すぎるとエラーを出し、入力内容を残したまま直せる" do
    sign_in_as(owner)
    set_viewport(375, 812)
    visit edit_business_project_path(project)

    # maxlength を外して、サーバー側の検証を確かめる。
    page.execute_script("document.getElementById('project_theme').removeAttribute('maxlength')")
    fill_in "project_theme", with: "あ" * 101
    click_button "保存する"

    expect(page).to have_css(".ba-errors[role='alert']", text: "テーマは100文字以内で入力してください")
    expect(page).to have_field("project_theme", with: "あ" * 101)
    shot("project_theme_error_375")
    expect(project.reload.theme).to eq "地域のお店の魅力発信"
  end
end
