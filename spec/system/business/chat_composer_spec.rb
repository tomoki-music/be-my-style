require "rails_helper"

# Business のプロジェクトチャット / コミュニティ タイムラインの入力欄を実ブラウザで確認する。
# 書式なしの入力欄・添付の選択と取り消し・スタンプ・画像の拡大表示・横はみ出し。
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

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  { "PC" => -> { use_desktop_viewport; @dom_input = true }, "スマホ" => -> { use_mobile_viewport } }.each do |label, viewport|
    it "#{label}: 書式なしの入力欄で、改行・日本語・HTML に似た文字を添付付きで送信できる" do
      sign_in_via_business_form
      instance_exec(&viewport)
      visit business_project_thread_path(project, ProjectThread.default_for(project))

      # 書式ボタン・プレビューは無く、本文の入力欄だけ。
      expect(page).to have_no_css("[role='toolbar'], [data-format], [data-composer-tab]")
      expect(page).to have_no_button("太字")
      expect(page).to have_no_button("プレビュー")
      expect(textarea[:rows]).to eq "3"

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

      body = "**画像を共有します**\n<b>太字ではない</b> <script>alert(1)</script>\n明日 10:00 から 5>3 の件"
      type_text(body)
      press(find_button("送信"))

      expect(page).to have_text("送信しました")
      chat = ProjectChat.last
      expect(chat).to be_content_format_plain
      # ブラウザはフォーム送信時に改行を CRLF にする(表示時に LF へそろえる)。
      expect(chat.body.gsub("\r\n", "\n")).to eq body
      expect(chat.attachments.map { |a| a.filename.to_s }).to eq ["photo.png"]
      within(".ba-post__body") do
        expect(page).to have_css(".business-chat-plain br", count: 2, visible: :all)
        expect(page).to have_text("**画像を共有します**")
        expect(page).to have_text("<b>太字ではない</b> <script>alert(1)</script>")
        expect(page).to have_text("明日 10:00 から 5>3 の件")
        expect(page).to have_no_css("strong, b, script")
        expect(page).to have_css("img.business-chat-images__thumb")
      end
      page.save_screenshot(Rails.root.join("tmp/screenshots/plain_composer_thread_#{label == "PC" ? 1280 : 375}.png").to_s)

      # サムネイルから拡大表示し、Esc で閉じる
      press(find(".business-chat-images__link"))
      expect(page).to have_css(".business-lightbox", visible: :visible)
      press_escape
      expect(page).to have_no_css(".business-lightbox", visible: :visible)

      expect(horizontal_overflow).to be <= 0
    end
  end

  { 1280 => -> { use_desktop_viewport; @dom_input = true }, 375 => -> { use_mobile_viewport } }.each do |width, viewport|
    it "幅#{width}px: タイムラインに書式なしで改行付きの投稿ができ、はみ出さない" do
      sign_in_via_business_form
      instance_exec(&viewport)
      visit business_community_path(community)

      expect(page).to have_no_css("[role='toolbar'], [data-composer-tab]")
      page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", textarea)
      page.save_screenshot(Rails.root.join("tmp/screenshots/plain_composer_timeline_#{width}.png").to_s)

      type_text("来週の定例について\n議題は https://example.com/agenda にまとめました。")
      press(find_button("投稿"))

      expect(page).to have_text("投稿しました")
      post = CommunityPost.last
      expect(post).to be_content_format_plain
      within(".ba-post__body", match: :first) do
        expect(page).to have_css(".business-chat-plain br", count: 1, visible: :all)
        expect(page).to have_link("https://example.com/agenda", href: "https://example.com/agenda")
      end
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
