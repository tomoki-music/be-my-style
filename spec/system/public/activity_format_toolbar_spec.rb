require "rails_helper"

# 活動報告フォームの文字装飾ツールバー(チャット欄と同じボタン+文字色+プレビュー。
# request_markdown_toolbar.js を共用)を実ブラウザで検証する。
#
# 注記: event_request_markdown_toolbar_spec.rb と同じ理由(この headless Chrome 環境では
# Selenium の実クリックが DOM フォーカスを移動させない既知の環境制約)により、
# 入力欄の値・選択範囲の設定とボタン押下は page.execute_script で行う。
RSpec.describe "活動報告の文字装飾ツールバー", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer, :customer_with_parts) }

  before { customer.update!(onboarding_done: true) }

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def set_field(id, value, selection_start:, selection_end:)
    page.execute_script(<<~JS)
      (function () {
        var el = document.getElementById(#{id.to_json});
        el.value = #{value.to_json};
        el.selectionStart = #{selection_start};
        el.selectionEnd = #{selection_end};
      })();
    JS
  end

  def click_format_button(field, action, color: nil)
    selector = %([data-markdown-toolbar-root="activity-#{field}"] [data-md-action="#{action}"])
    selector += %([data-md-color="#{color}"]) if color
    page.execute_script("document.querySelector(#{selector.to_json}).click();")
  end

  def field_value(id)
    page.evaluate_script("document.getElementById(#{id.to_json}).value")
  end

  def field_selection(id)
    page.evaluate_script("(function () { var el = document.getElementById(#{id.to_json}); return [el.selectionStart, el.selectionEnd]; })()")
  end

  def apply_color(field, color)
    click_format_button(field, "color-menu")
    expect(page).to have_selector(%([data-markdown-toolbar-root="activity-#{field}"] [data-md-color-palette]), visible: true)
    click_format_button(field, "color", color: color)
  end

  it "Markdown 本文欄の4つだけにツールバーが付き、ボタンは type=button" do
    sign_in_via_form(customer)
    visit new_public_activity_path

    expect(page).to have_selector("[data-markdown-toolbar-root^='activity-']", count: 4)
    %w[keep problem try introduction].each do |field|
      expect(page).to have_selector(%([data-markdown-toolbar-root="activity-#{field}"] #activity_#{field}))
    end
    expect(page).not_to have_selector("[data-markdown-toolbar-root] #activity_title")
    expect(page).not_to have_selector("[data-markdown-toolbar-root] #activity_url")

    types = page.evaluate_script(
      "Array.from(document.querySelectorAll('[data-markdown-toolbar-root^=\"activity-\"] button')).map(function (b) { return b.type; })"
    )
    expect(types).to all(eq("button"))
  end

  FIELDS = %w[keep problem try introduction].freeze
  EXPECTED_ACTIONS = %w[
    bold italic heading strikethrough quote unordered-list ordered-list checklist
    code codeblock link image hr color-menu preview
  ].freeze

  def toolbar_actions(field)
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('[data-markdown-toolbar-root="activity-#{field}"] .activity-format-toolbar__btn'))
        .map(function (b) { return b.dataset.mdAction; })
    JS
  end

  it "4欄それぞれにチャット欄と同じボタン・文字色・プレビューが並ぶ" do
    sign_in_via_form(customer)
    visit new_public_activity_path

    FIELDS.each do |field|
      expect(toolbar_actions(field)).to eq(EXPECTED_ACTIONS)
      expect(page).to have_selector("textarea#activity_#{field}")
    end
  end

  it "追加したボタンは選択範囲・複数行に適用され、押した欄だけが変わる" do
    sign_in_via_form(customer)
    visit new_public_activity_path

    set_field("activity_keep", "良かった", selection_start: 0, selection_end: 4)
    click_format_button(:keep, "italic")
    expect(field_value("activity_keep")).to eq("*良かった*")

    set_field("activity_problem", "音が小さい", selection_start: 0, selection_end: 1)
    click_format_button(:problem, "strikethrough")
    expect(field_value("activity_problem")).to eq("~~音~~が小さい")

    set_field("activity_try", "練習", selection_start: 0, selection_end: 2)
    click_format_button(:try, "code")
    expect(field_value("activity_try")).to eq("`練習`")

    lines = "行1\n行2\n行3"
    {
      "quote" => "> 行1\n> 行2\n> 行3",
      "unordered-list" => "- 行1\n- 行2\n- 行3",
      "ordered-list" => "1. 行1\n2. 行2\n3. 行3",
      "checklist" => "- [ ] 行1\n- [ ] 行2\n- [ ] 行3"
    }.each do |action, expected|
      set_field("activity_introduction", lines, selection_start: 0, selection_end: lines.length)
      click_format_button(:introduction, action)
      expect(field_value("activity_introduction")).to eq(expected)
    end

    set_field("activity_introduction", "前x後", selection_start: 1, selection_end: 2)
    click_format_button(:introduction, "codeblock")
    expect(field_value("activity_introduction")).to eq("前\n```\nx\n```\n後")

    set_field("activity_introduction", "", selection_start: 0, selection_end: 0)
    click_format_button(:introduction, "image")
    expect(field_value("activity_introduction")).to eq("![画像の説明](https://)")
    expect(field_selection("activity_introduction")).to eq([9, 17])

    set_field("activity_introduction", "公式サイト", selection_start: 2, selection_end: 5)
    click_format_button(:introduction, "link")
    expect(field_value("activity_introduction")).to eq("公式[サイト](https://)")
    expect(field_selection("activity_introduction")).to eq([8, 16])

    set_field("activity_introduction", "本文", selection_start: 2, selection_end: 2)
    click_format_button(:introduction, "hr")
    expect(field_value("activity_introduction")).to eq("本文\n\n---\n")

    # 他の欄の操作で、先に装飾した欄は変わらない
    expect(field_value("activity_keep")).to eq("*良かった*")
    expect(field_value("activity_problem")).to eq("~~音~~が小さい")
    expect(field_value("activity_try")).to eq("`練習`")

    expect(page).to have_current_path(new_public_activity_path)
    expect(Activity.count).to eq(0)
  end

  it "プレビューは詳細画面と同じ描画で文字色も確認でき、押した欄だけが切り替わる" do
    sign_in_via_form(customer)
    visit new_public_activity_path

    set_field("activity_introduction", "**太字** {color:red}赤い文字{/color}\n\n- [ ] やること", selection_start: 0, selection_end: 0)
    click_format_button(:introduction, "preview")

    root = '[data-markdown-toolbar-root="activity-introduction"]'
    within(root) do
      expect(page).to have_selector(".request-markdown-toolbar__preview-body strong", text: "太字", wait: 10)
      expect(page).to have_selector(".request-markdown-toolbar__preview-body span.md-text-color--red", text: "赤い文字")
      expect(page).to have_selector(".request-markdown-toolbar__preview-body li.md-task-item", text: "☐ やること")
      expect(page).to have_selector("#activity_introduction", visible: :hidden)
      expect(page).to have_selector('[data-md-action="preview"][aria-pressed="true"]', text: "編集に戻る")
    end
    red = page.evaluate_script("getComputedStyle(document.querySelector('#{root} .md-text-color--red')).color")
    expect(red).to eq("rgb(211, 47, 47)")
    expect(page).to have_selector("#activity_keep", visible: true)

    click_format_button(:introduction, "preview")
    expect(page).to have_selector("#activity_introduction", visible: true)
    expect(page).to have_selector("#{root} .activity-format-preview", visible: :hidden)
    expect(Activity.count).to eq(0)
  end

  it "選択した部分だけを装飾し、未選択ならひな形を選択状態で入れる(フォームは送信されない)" do
    sign_in_via_form(customer)
    visit new_public_activity_path

    set_field("activity_keep", "とても良かった", selection_start: 3, selection_end: 7)
    click_format_button(:keep, "bold")
    expect(field_value("activity_keep")).to eq("とても**良かった**")
    expect(field_selection("activity_keep")).to eq([5, 9])

    set_field("activity_problem", "音が小さかった", selection_start: 0, selection_end: 2)
    apply_color(:problem, "red")
    expect(field_value("activity_problem")).to eq("{color:red}音が{/color}小さかった")
    expect(page).to have_selector('[data-markdown-toolbar-root="activity-problem"] [data-md-color-palette]', visible: :hidden)

    set_field("activity_try", "次は", selection_start: 2, selection_end: 2)
    click_format_button(:try, "bold")
    expect(field_value("activity_try")).to eq("次は**太字にする文字**")
    expect(field_selection("activity_try")).to eq([4, 11])

    set_field("activity_introduction", "", selection_start: 0, selection_end: 0)
    apply_color(:introduction, "blue")
    expect(field_value("activity_introduction")).to eq("{color:blue}色を付ける文字{/color}")
    expect(field_selection("activity_introduction")).to eq([12, 19])

    expect(page).to have_current_path(new_public_activity_path)
    expect(Activity.count).to eq(0)
  end

  it "保存後に太字・文字色が表示され、再編集で記法が残り、更新も反映される" do
    sign_in_via_form(customer)
    visit new_public_activity_path

    fill_in "activity_title", with: "セッション報告"
    set_field("activity_keep", "とても良かった", selection_start: 3, selection_end: 7)
    click_format_button(:keep, "bold")
    set_field("activity_problem", "音が小さかった", selection_start: 0, selection_end: 7)
    apply_color(:problem, "red")
    fill_in "activity_try", with: "練習する"
    set_field("activity_introduction", "## 直接入力の見出し\n\n- 項目\n\nここを緑に", selection_start: 22, selection_end: 24)
    apply_color(:introduction, "green")

    accept_confirm { click_button "活動報告を登録" }
    expect(page).to have_content("活動報告の投稿が完了しました", wait: 10)

    activity = Activity.last
    expect(activity.keep).to eq("とても**良かった**")
    expect(activity.problem).to eq("{color:red}音が小さかった{/color}")

    # 一覧カードには記法を出さない
    expect(page).to have_content("とても良かった")
    expect(page).not_to have_content("**良かった**")
    expect(page).not_to have_content("{color:red}")

    visit public_activity_path(activity)
    expect(page).to have_selector(".activity-show-kpt-body strong", text: "良かった")
    expect(page).to have_selector(".activity-show-kpt-body span.md-text-color--red", text: "音が小さかった")
    expect(page).to have_selector(".markdown-body h2", text: "直接入力の見出し")
    expect(page).to have_selector(".markdown-body li", text: "項目")
    expect(page).to have_selector(".markdown-body span.md-text-color--green", text: "緑に")
    red = page.evaluate_script("getComputedStyle(document.querySelector('.md-text-color--red')).color")
    expect(red).to eq("rgb(211, 47, 47)")

    visit edit_public_activity_path(activity)
    expect(field_value("activity_keep")).to eq("とても**良かった**")
    expect(field_value("activity_problem")).to eq("{color:red}音が小さかった{/color}")

    set_field("activity_try", "練習する", selection_start: 0, selection_end: 4)
    apply_color(:try, "purple")
    accept_confirm { click_button "活動報告を登録" }
    expect(page).to have_content("活動報告の編集が完了しました", wait: 10)
    expect(page).to have_selector(".activity-show-kpt-body span.md-text-color--purple", text: "練習する")
    expect(page).to have_selector(".activity-show-kpt-body strong", text: "良かった")
  end

  it "スマホ幅でもツールバーが画面内に収まり、操作できる" do
    sign_in_via_form(customer)
    use_mobile_viewport
    visit new_public_activity_path

    click_format_button(:keep, "color-menu")
    overflow = page.evaluate_script(<<~JS)
      (function () {
        var width = document.documentElement.clientWidth;
        return Array.from(document.querySelectorAll('.activity-new-edit-table, .activity-format-toolbar, .activity-format-toolbar__btn, .activity-format-toolbar__swatch'))
          .filter(function (el) { return el.offsetParent !== null; })
          .filter(function (el) { return el.getBoundingClientRect().right > width + 1; })
          .map(function (el) { return el.className; });
      })()
    JS
    expect(overflow).to eq([])

    # 4欄の全ボタンが画面内に表示され、押せる大きさがある
    hidden_or_small = page.evaluate_script(<<~JS)
      (function () {
        var width = document.documentElement.clientWidth;
        return Array.from(document.querySelectorAll('.activity-format-toolbar__btn'))
          .filter(function (el) {
            var r = el.getBoundingClientRect();
            return el.offsetParent === null || r.left < 0 || r.right > width + 1 || r.height < 36;
          })
          .map(function (el) { return el.dataset.mdAction; });
      })()
    JS
    expect(hidden_or_small).to eq([])
    expect(page.all(".activity-format-toolbar__btn").size).to eq(EXPECTED_ACTIONS.size * FIELDS.size)

    set_field("activity_problem", "a\nb", selection_start: 0, selection_end: 3)
    click_format_button(:problem, "checklist")
    expect(field_value("activity_problem")).to eq("- [ ] a\n- [ ] b")

    set_field("activity_keep", "楽しかった", selection_start: 0, selection_end: 5)
    click_format_button(:keep, "color", color: "orange")
    expect(field_value("activity_keep")).to eq("{color:orange}楽しかった{/color}")
  end
end
