require "rails_helper"

# みんなのリクエスト欄(#input_request)に追加したMarkdown入力補助ツールバー
# (request_markdown_toolbar.js)の挙動を実ブラウザで検証する。
#
# 注記: event_request_mention_spec.rbと同じ理由(このheadless Chrome環境ではSeleniumの
# 実クリックがDOMフォーカスを移動させない既知の環境制約)により、Capybaraの実クリックではなく
# page.execute_scriptでボタンのclick()やtextareaのvalue/selectionStart/selectionEndを
# 直接操作する方式で検証する。
RSpec.describe "みんなのリクエストのMarkdown入力補助ツールバー", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:owner) { create(:customer, :customer_with_parts) }
  let(:community) { create(:community) }
  let(:event) { create(:event, :event_with_songs, customer: owner, community: community) }

  before do
    owner.create_subscription!(status: "active", plan: "core")
    owner.update!(onboarding_done: true)
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def set_request_value(value, selection_start:, selection_end:)
    page.execute_script(<<~JS)
      (function () {
        var el = document.querySelector('#input_request');
        el.value = #{value.to_json};
        el.selectionStart = #{selection_start};
        el.selectionEnd = #{selection_end};
      })();
    JS
  end

  def click_toolbar_button(action)
    page.execute_script(<<~JS)
      (function () {
        document.querySelector('.request-markdown-toolbar__btn[data-md-action="#{action}"]').click();
      })();
    JS
  end

  def request_textarea_value
    page.evaluate_script("document.querySelector('#input_request').value")
  end

  def request_textarea_selection
    page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector('#input_request');
        return [el.selectionStart, el.selectionEnd];
      })();
    JS
  end

  it "リクエスト欄にのみツールバーが表示される" do
    sign_in_via_form(owner)
    visit public_event_path(event)

    expect(page).to have_selector('[data-markdown-toolbar-root="request"]', count: 1)
    expect(page).to have_content("見出し")
    expect(page).to have_content("太字")
    expect(page).to have_content("箇条書き")
    expect(page).to have_content("番号リスト")
    expect(page).to have_content("引用")
    expect(page).to have_content("リンク")
    expect(page).to have_content("プレビュー")
    expect(page).to have_content("文字を選択して、上のボタンから装飾できます")
  end

  it "ツールバーの各ボタンはtype=\"button\"であり、フォーム誤送信を起こさない" do
    sign_in_via_form(owner)
    visit public_event_path(event)

    types = page.evaluate_script(<<~JS)
      Array.prototype.map.call(document.querySelectorAll('.request-markdown-toolbar__btn'), function (b) { return b.getAttribute('type'); })
    JS
    expect(types).to all(eq("button"))

    expect do
      click_toolbar_button("bold")
      click_toolbar_button("heading")
      click_toolbar_button("preview")
    end.not_to change(Request, :count)
    expect(page).to have_current_path(public_event_path(event))
  end

  it "太字ボタンで選択文字を**で囲み、未選択時はプレースホルダーを挿入して選択状態にする" do
    sign_in_via_form(owner)
    visit public_event_path(event)

    set_request_value("テスト", selection_start: 0, selection_end: 3)
    click_toolbar_button("bold")
    expect(request_textarea_value).to eq("**テスト**")

    set_request_value("", selection_start: 0, selection_end: 0)
    click_toolbar_button("bold")
    expect(request_textarea_value).to eq("**太字にする文字**")
    expect(request_textarea_selection).to eq([2, 2 + "太字にする文字".length])
  end

  it "見出しボタンで行頭に## を挿入し、既に見出し記号がある行では重複挿入しない" do
    sign_in_via_form(owner)
    visit public_event_path(event)

    set_request_value("テスト", selection_start: 0, selection_end: 3)
    click_toolbar_button("heading")
    expect(request_textarea_value).to eq("## テスト")

    set_request_value("", selection_start: 0, selection_end: 0)
    click_toolbar_button("heading")
    expect(request_textarea_value).to eq("## 見出し")

    set_request_value("## 見出し済み", selection_start: 0, selection_end: 0)
    click_toolbar_button("heading")
    expect(request_textarea_value).to eq("## 見出し済み")
  end

  it "箇条書き・番号リスト・引用ボタンで複数行それぞれの先頭に記号を付与する" do
    sign_in_via_form(owner)
    visit public_event_path(event)

    set_request_value("曲A\n曲B", selection_start: 0, selection_end: "曲A\n曲B".length)
    click_toolbar_button("unordered-list")
    expect(request_textarea_value).to eq("- 曲A\n- 曲B")

    set_request_value("曲A\n曲B", selection_start: 0, selection_end: "曲A\n曲B".length)
    click_toolbar_button("ordered-list")
    expect(request_textarea_value).to eq("1. 曲A\n2. 曲B")

    set_request_value("曲A\n曲B", selection_start: 0, selection_end: "曲A\n曲B".length)
    click_toolbar_button("quote")
    expect(request_textarea_value).to eq("> 曲A\n> 曲B")

    set_request_value("", selection_start: 0, selection_end: 0)
    click_toolbar_button("unordered-list")
    expect(request_textarea_value).to eq("- 項目")

    set_request_value("", selection_start: 0, selection_end: 0)
    click_toolbar_button("ordered-list")
    expect(request_textarea_value).to eq("1. 項目")
  end

  it "リンクボタンで選択文字をリンク名にし、未選択時はURL部分を選択状態にする(prompt()は使わない)" do
    sign_in_via_form(owner)
    visit public_event_path(event)

    set_request_value("参考動画", selection_start: 0, selection_end: "参考動画".length)
    click_toolbar_button("link")
    expect(request_textarea_value).to eq("[参考動画](https://)")

    set_request_value("", selection_start: 0, selection_end: 0)
    click_toolbar_button("link")
    expect(request_textarea_value).to eq("[リンク名](https://)")
    url_start = "[リンク名](".length
    expect(request_textarea_selection).to eq([url_start, url_start + "https://".length])
  end

  it "プレビューボタンで編集⇔表示を切り替えられ、入力内容は保持され、空欄時は案内文が出る" do
    sign_in_via_form(owner)
    visit public_event_path(event)

    set_request_value("**強調**の確認", selection_start: 0, selection_end: 0)
    click_toolbar_button("preview")

    expect(page).to have_selector(".request-markdown-toolbar__pane--preview:not([hidden])", wait: 10)
    within(".request-markdown-toolbar__preview-body") do
      expect(page).to have_selector("strong", text: "強調", wait: 10)
    end

    click_toolbar_button("preview")
    expect(page).to have_selector(".request-markdown-toolbar__pane--edit:not([hidden])")
    expect(request_textarea_value).to eq("**強調**の確認")

    set_request_value("", selection_start: 0, selection_end: 0)
    click_toolbar_button("preview")
    within(".request-markdown-toolbar__preview-body") do
      expect(page).to have_content("プレビューする内容がありません")
    end
  end

  # event_form_mobile_overflow_spec.rbと同じ理由(実機/実ブラウザが使えない、
  # page.current_window.resize_toではこの環境のheadless Chromeで320〜414pxを
  # 再現できない)により、CDPのEmulation.setDeviceMetricsOverrideでモバイル幅を再現する。
  def set_mobile_viewport(width, height = 812)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 2, mobile: true
    )
  end

  # イベント詳細画面(public_event_path)には、本仕様と無関係な既存の横スクロール要因
  # (.event-songs-table、パート選択チェックボックス列等、table-layout: autoで
  # 縮まないセルを含む楽曲一覧)が本ツールバーの実装前から存在する
  # (event_form_mobile_overflow_spec.rbが対象とする編集画面用.event-tableとは別物で、
  # このリポジトリの現状では未対応)。そのためページ全体のscrollWidthでは本ツールバー
  # による横スクロールの有無を切り分けられず、ここでは「.request-markdown-toolbar
  # 自身とその子要素(ボタン・textarea・プレビュー領域)が画面幅内に収まっているか」を
  # 直接検証する。
  def expect_toolbar_within_viewport(client_width)
    max_right = page.evaluate_script(<<~JS)
      (function () {
        var root = document.querySelector('.request-markdown-toolbar');
        var maxRight = root.getBoundingClientRect().right;
        root.querySelectorAll('*').forEach(function (el) {
          var right = el.getBoundingClientRect().right;
          if (right > maxRight) maxRight = right;
        });
        return maxRight;
      })()
    JS
    expect(max_right).to be <= client_width + 1 # サブピクセル誤差許容
  end

  context "スマートフォン幅表示" do
    [320, 375, 390].each do |width|
      it "#{width}px幅でツールバー自身が画面幅内に収まり、横スクロールを増やさないこと" do
        sign_in_via_form(owner)
        set_mobile_viewport(width)

        visit public_event_path(event)
        expect(page).to have_selector('[data-markdown-toolbar-root="request"]')

        client_width = page.evaluate_script("document.documentElement.clientWidth")
        expect_toolbar_within_viewport(client_width)
      end
    end
  end

  it "二重初期化してもボタンのイベントが重複登録されない" do
    sign_in_via_form(owner)
    visit public_event_path(event)

    page.execute_script(<<~JS)
      (function () {
        var root = document.querySelector('[data-markdown-toolbar-root="request"]');
        window.RequestMarkdownToolbar.init(root);
        window.RequestMarkdownToolbar.init(root);
      })();
    JS

    set_request_value("テスト", selection_start: 0, selection_end: 3)
    click_toolbar_button("bold")

    expect(request_textarea_value).to eq("**テスト**")
  end
end
