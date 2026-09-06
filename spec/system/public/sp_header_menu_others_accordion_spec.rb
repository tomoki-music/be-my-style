require "rails_helper"

# スマホヘッダーメニュー(.customer-menu-sp)の情報整理:
#   - 主要導線 + 「その他」アコーディオン(details.menu-sp-others) + アカウント欄
# を実ブラウザ幅で検証する。
#   - 「その他」は初期状態で閉じている / タップで開閉できる
#   - aria-expanded が開閉状態と同期する
#   - メニュー内リンクを押しても「その他」トグルはメニュー全体を閉じない
#   - 375px / 320px 幅で横スクロールが出ない
RSpec.describe "スマホヘッダー: 「その他」アコーディオン", type: :system, js: true do
  let(:customer) { create(:customer, name: "SPメニュー確認ユーザー") }

  def sign_in_via_form(target)
    visit new_customer_session_path
    fill_in "customer_email", with: target.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  # #open は sticky ヘッダー内にあり、この環境の headless ではネイティブクリックが
  # イベント化されないことがあるため JS の .click() で開く(既存 header spec と同方針)。
  def open_sp_menu
    page.execute_script("document.getElementById('open').click()")
    expect(page).to have_css(".customer-menu-sp.show", visible: :all)
  end

  # <summary> も固定オーバーレイ内にあり、位置によってはネイティブクリックが
  # 届かないため JS の .click() でトグルする(ネイティブ <details> の既定動作は発火する)。
  def toggle_others
    page.execute_script("document.querySelector('summary.menu-sp-others__toggle').click()")
  end

  before do
    sign_in_via_form(customer)
    use_mobile_viewport(width: 375)
    visit public_customer_feedbacks_path
    open_sp_menu
  end

  it "「その他」は初期状態で閉じており、配下リンクは非表示" do
    expect(page).to have_css("details.menu-sp-others")
    expect(page).not_to have_css("details.menu-sp-others[open]")

    summary = find("summary.menu-sp-others__toggle")
    expect(summary["aria-expanded"]).to eq("false")
    expect(summary["aria-controls"]).to eq("sp-menu-others-panel")

    expect(page).to have_css("#sp-menu-others-panel a", text: "ご意見BOX", visible: :hidden)
  end

  it "タップで開き、再タップで閉じる。aria-expanded も同期する" do
    toggle_others
    expect(page).to have_css("details.menu-sp-others[open]")
    expect(find("summary.menu-sp-others__toggle")["aria-expanded"]).to eq("true")
    expect(page).to have_css("#sp-menu-others-panel a", text: "ご意見BOX", visible: :visible)
    # 「その他」を開いても SP メニュー自体は開いたまま
    expect(page).to have_css(".customer-menu-sp.show", visible: :all)

    toggle_others
    expect(page).not_to have_css("details.menu-sp-others[open]")
    expect(find("summary.menu-sp-others__toggle")["aria-expanded"]).to eq("false")
  end

  it "「その他」配下のリンクを押すと遷移する(メニュー開閉処理が干渉しない)" do
    toggle_others
    expect(page).to have_css("details.menu-sp-others[open]")

    click_link "ご意見BOX"
    expect(page).to have_current_path(new_public_customer_feedback_path, wait: 10)
  end

  it "アカウント欄のマイページ / ログアウトは常時表示される(アコーディオンの外)" do
    within(".customer-menu-sp__account") do
      expect(page).to have_link("マイページ", href: public_customer_path(customer))
      expect(page).to have_button("ログアウト")
    end
  end

  it "375px 幅で横スクロールが発生しない" do
    overflow = page.evaluate_script(
      "document.documentElement.scrollWidth - document.documentElement.clientWidth"
    )
    expect(overflow).to be <= 1

    toggle_others
    expect(page).to have_css("details.menu-sp-others[open]")
    overflow_open = page.evaluate_script(
      "document.documentElement.scrollWidth - document.documentElement.clientWidth"
    )
    expect(overflow_open).to be <= 1
  end

  it "320px 幅でもメニューが画面外へはみ出さない" do
    use_mobile_viewport(width: 320)
    visit public_customer_feedbacks_path
    open_sp_menu
    toggle_others
    expect(page).to have_css("details.menu-sp-others[open]")

    overflow = page.evaluate_script(
      "document.documentElement.scrollWidth - document.documentElement.clientWidth"
    )
    expect(overflow).to be <= 1
  end
end
