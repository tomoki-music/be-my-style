require "rails_helper"

# Business のプロジェクトチャット / コミュニティ タイムラインの入力欄を実ブラウザで確認する。
# 書式ボタン・プレビュー・添付の選択と取り消し・スタンプ・画像の拡大表示・横はみ出し。
RSpec.describe "Business チャット入力欄", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:member) { create(:customer, name: "チャット確認ユーザー", domain_name: "business", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "新規事業", description: "説明") }
  let(:fixtures) { Rails.root.join("spec/fixtures/files/business_chat") }

  before do
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: member, community: community)
    project.members << member
  end

  def sign_in_via_business_form
    visit new_business_customer_session_path
    fill_in "customer_email", with: member.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_current_path(business_root_path, wait: 10)
  end

  def textarea
    find(".business-composer__textarea")
  end

  # PC 版はヘッダーが position: sticky になり、ローカルの headless Chrome ではネイティブの
  # クリック・キー入力がイベント化されない既知の問題がある(PR #178)。PC では DOM 経由で操作する。
  def press(element)
    @dom_input ? page.execute_script("arguments[0].click()", element) : element.click
  end

  # PC(DOM 操作)ではページにフォーカスが無く prompt が表示されないため、入力値を返すスタブにする。
  def answer_prompt(value, &block)
    return accept_prompt(with: value, &block) unless @dom_input

    page.execute_script("window.prompt = function () { return #{value.to_json}; }")
    block.call
  end

  def type_text(text)
    if @dom_input
      page.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input'))", textarea, text)
    else
      textarea.set(text)
    end
  end

  def press_escape
    if @dom_input
      page.execute_script("document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))")
    else
      find("body").send_keys(:escape)
    end
  end

  def select_all_text
    page.execute_script("var t=document.querySelector('.business-composer__textarea');t.focus();t.setSelectionRange(0,t.value.length);")
  end

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  { "PC" => -> { use_desktop_viewport; @dom_input = true }, "スマホ" => -> { use_mobile_viewport } }.each do |label, viewport|
    it "#{label}: 書式ボタン・プレビュー・添付の取り消しを使って送信できる" do
      sign_in_via_business_form
      instance_exec(&viewport)
      visit business_project_path(project)

      # 未選択で押すと入力例が入る
      press(find_button("太字"))
      expect(textarea.value).to eq "**太字にしたい文字**"

      # 選択した文字に書式を付ける
      type_text("今週の予定")
      select_all_text
      press(find_button("大きい文字"))
      expect(textarea.value).to eq "## 今週の予定"

      type_text("資料作成\n日程調整")
      select_all_text
      press(find_button("箇条書き"))
      expect(textarea.value).to eq "- 資料作成\n- 日程調整"

      type_text("参考資料")
      select_all_text
      answer_prompt("https://example.com/doc") { press(find_button("リンク")) }
      expect(textarea.value).to eq "[参考資料](https://example.com/doc)"

      type_text("**太字** <script>alert(1)</script>\n\n- 項目")
      press(find_button("プレビュー"))
      within(".business-composer__preview") do
        expect(page).to have_css("strong", text: "太字")
        expect(page).to have_css("li", text: "項目")
        expect(page).to have_no_css("script")
      end
      press(find_button("入力"))
      expect(page).to have_css(".business-composer__textarea", visible: :visible)

      # 添付: 2件選んで1件取り消す
      attach_file "project_chat[attachments][]", [fixtures.join("photo.png"), fixtures.join("sample.pdf")], make_visible: true
      expect(page).to have_css(".business-composer__file", count: 2)
      press(find("button[aria-label='「sample.pdf」の添付を取り消す']"))
      expect(page).to have_css(".business-composer__file", count: 1)
      expect(page).to have_text("photo.png")

      # 許可しない形式は画面でも案内する
      attach_file "project_chat[attachments][]", fixtures.join("tool.exe"), make_visible: true
      expect(page).to have_css(".business-composer__error", text: "「tool.exe」は添付できない形式です。")
      expect(page).to have_css(".business-composer__file", count: 1)

      expect(horizontal_overflow).to be <= 0

      type_text("**画像を共有します**")
      press(find_button("送信"))

      expect(page).to have_text("送信しました")
      chat = ProjectChat.last
      expect(chat.attachments.map { |a| a.filename.to_s }).to eq ["photo.png"]
      within(".chat-body") do
        expect(page).to have_css("strong", text: "画像を共有します")
        expect(page).to have_css("img.business-chat-images__thumb")
      end

      # サムネイルから拡大表示し、Esc で閉じる
      press(find(".business-chat-images__link"))
      expect(page).to have_css(".business-lightbox", visible: :visible)
      press_escape
      expect(page).to have_no_css(".business-lightbox", visible: :visible)

      expect(horizontal_overflow).to be <= 0
    end
  end

  it "タイムラインでスタンプだけを送信できる" do
    sign_in_via_business_form
    use_mobile_viewport
    visit business_community_path(community)

    # 実ウィンドウより縦長の画面を模しているため、下端付近の要素は中央へスクロールしてから押す。
    toggle = find(".business-stamp-picker .stamp-picker__toggle")
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", toggle)
    toggle.click
    accept_confirm { find("button[aria-label='ありがとうスタンプを送信']").click }

    expect(page).to have_text("投稿しました")
    expect(CommunityPost.last.stamp_type).to eq "thanks"
    expect(page).to have_css(".business-chat-stamp img[alt='ありがとう']")
    expect(horizontal_overflow).to be <= 0
  end
end
