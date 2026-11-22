require "rails_helper"

# プライベートプロジェクトの招待リンクの発行・コピーと、受け入れ画面からの参加を実ブラウザ(スマホ幅)で確認する。データはすべて架空。
RSpec.describe "Business プライベートプロジェクトの招待", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true, name: "青山 葵") }
  let(:invitee) { create(:customer, domain_name: "business", onboarding_done: true, name: "招待 太郎") }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "地域企画ラボ") }
  let!(:project) do
    Project.create!(community: community, customer: owner, title: "非公開の新商品企画", theme: "発売前の相談",
                    description: "社外秘の内容です。", visibility: :private)
  end

  before { CommunityCustomer.create!(community: community, customer: owner) }

  def set_viewport(width, height = 900)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: width < 600
    )
  end

  def sign_in_as(target, expected_path: business_root_path)
    visit new_business_customer_session_path
    fill_in "customer_email", with: target.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_current_path(expected_path, wait: 10)
  end

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  it "オーナーが招待リンクを発行し、招待された人が未ログインで開いてログイン・参加すると、プロジェクトへ進む" do
    sign_in_as(owner)
    set_viewport(375)
    visit business_project_invitation_link_path(project)
    expect(page).to have_content("招待リンクはまだ発行されていません")
    select "30日間", from: "有効期限"
    click_button "発行する"
    expect(page).to have_content("発行した招待リンク")
    expect(page).to have_button("リンクをコピー", visible: true)
    expect(horizontal_overflow).to be <= 0
    url = find("#invitation-link-url").value
    path = URI.parse(url).request_uri

    # 別の人(未ログイン)としてリンクを開く。
    page.driver.browser.manage.delete_all_cookies

    visit path
    expect(page).to have_current_path(business_project_invitation_path)
    expect(page).to have_css("#invite-title", text: "非公開の新商品企画")
    expect(page).not_to have_content("社外秘の内容です。")
    expect(horizontal_overflow).to be <= 0

    click_link "ログインして参加する"
    fill_in "customer_email", with: invitee.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_current_path(business_project_invitation_path, wait: 10)
    expect(horizontal_overflow).to be <= 0

    click_button "参加する"
    expect(page).to have_current_path(business_project_path(project), wait: 10)
    expect(page).to have_content("プロジェクトに参加しました")
    expect(page).to have_content("社外秘の内容です。")
    expect(invitee.business_project_participant?(project)).to be true
  end

  it "プライベートからの変更の確認画面は、スマホ幅でも横にはみ出さない" do
    sign_in_as(owner)
    set_viewport(375)
    visit edit_business_project_visibility_path(project, to: "listed")
    expect(page).to have_content("閲覧できる範囲が広がります")
    expect(horizontal_overflow).to be <= 0
  end
end
