require "rails_helper"

# Business のスタンプ選択(「シンプル」「動物」タブ)を実ブラウザで確認する。
# タブ切替・矢印キー操作・aria 状態・全画像の読み込み・送信と表示・横はみ出し。
RSpec.describe "Business スタンプ選択", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:member) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "新規事業", description: "説明") }

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

  # PC 版は sticky ヘッダーのため headless Chrome でネイティブのクリック・キー入力が
  # イベント化されない既知の問題がある(PR #178)。PC では DOM 経由で操作する。
  # スマホは CDP で 390x844 を模しているが実ウィンドウは小さく、画面下端付近へのネイティブクリックが
  # 取りこぼされるため、押す前に要素を画面中央へスクロールする。
  def press(element)
    return page.execute_script("arguments[0].click()", element) if @dom_input

    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", element)
    element.click
  end

  def press_key(element, key)
    if @dom_input
      page.execute_script("arguments[0].dispatchEvent(new KeyboardEvent('keydown', { key: arguments[1], bubbles: true }))", element, key)
    else
      element.send_keys(key == "ArrowRight" ? :right : key == "ArrowLeft" ? :left : key.downcase.to_sym)
    end
  end

  # PC(DOM 操作)ではページにフォーカスが無く confirm が表示されないため、承諾するスタブにする。
  def confirm_and_send(&block)
    return accept_confirm(&block) unless @dom_input

    page.execute_script("window.confirm = function () { return true; }")
    block.call
  end

  def tab(label)
    find(".business-stamp-picker [role='tab']", text: label)
  end

  def selected_tab_label
    find(".business-stamp-picker [role='tab'][aria-selected='true']").text
  end

  def visible_stamp_count
    all(".business-stamp-picker [role='tabpanel']:not([hidden]) .stamp-choice").size
  end

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  # loading="lazy" の画像は表示位置に来るまで読まれないため、同じ URL を別途読み込んで壊れていないか確かめる。
  def broken_stamp_images
    page.evaluate_async_script(<<~JS)
      var done = arguments[arguments.length - 1];
      var srcs = Array.from(document.querySelectorAll('.business-stamp-picker .stamp-choice__img')).map(function (img) { return img.src; });
      Promise.all(srcs.map(function (src) {
        return new Promise(function (resolve) {
          var image = new Image();
          image.onload = function () { resolve(image.naturalWidth > 0 ? null : src); };
          image.onerror = function () { resolve(src); };
          image.src = src;
        });
      })).then(function (results) { done({ total: srcs.length, broken: results.filter(Boolean) }); });
    JS
  end

  { "PC" => -> { use_desktop_viewport; @dom_input = true }, "スマホ" => -> { use_mobile_viewport } }.each do |label, viewport|
    it "#{label}: タブを切り替えて両タブのスタンプを選択・送信できる" do
      sign_in_via_business_form
      instance_exec(&viewport)
      visit business_community_path(community)

      press(find(".business-stamp-picker .stamp-picker__toggle"))
      expect(page).to have_css(".business-stamp-picker .stamp-picker__panel", visible: :visible)

      expect(broken_stamp_images).to eq("total" => 26, "broken" => [])
      expect(selected_tab_label).to eq "シンプル"
      expect(visible_stamp_count).to eq 20
      expect(horizontal_overflow).to be <= 0

      press(tab("動物"))
      expect(selected_tab_label).to eq "動物"
      expect(tab("動物")["tabindex"]).to eq "0"
      expect(tab("シンプル")["tabindex"]).to eq "-1"
      expect(visible_stamp_count).to eq 6
      expect(horizontal_overflow).to be <= 0
      page.save_screenshot(Rails.root.join("tmp/screenshots/business_stamp_picker_#{label == 'PC' ? 'pc' : 'sp'}_animal.png").to_s)

      # 矢印キー / Home / End でタブを移動できる
      press_key(tab("動物"), "ArrowRight")
      expect(selected_tab_label).to eq "シンプル"
      press_key(tab("シンプル"), "ArrowLeft")
      expect(selected_tab_label).to eq "動物"
      press_key(tab("動物"), "Home")
      expect(selected_tab_label).to eq "シンプル"
      expect(visible_stamp_count).to eq 20
      page.save_screenshot(Rails.root.join("tmp/screenshots/business_stamp_picker_#{label == 'PC' ? 'pc' : 'sp'}_simple.png").to_s)
      press_key(tab("シンプル"), "End")
      expect(selected_tab_label).to eq "動物"

      confirm_and_send { press(find("button[aria-label='わーい！スタンプを送信']")) }
      expect(page).to have_text("投稿しました")
      expect(CommunityPost.last.stamp_type).to eq "animal_yay"
      expect(page).to have_css(".business-chat-stamp img[alt='わーい！']")

      press(find(".business-stamp-picker .stamp-picker__toggle"))
      confirm_and_send { press(find("button[aria-label='快調です（人物）スタンプを送信']")) }
      expect(page).to have_text("投稿しました")
      expect(CommunityPost.last.stamp_type).to eq "character_doing_great"
      expect(horizontal_overflow).to be <= 0
    end
  end

  it "スマホ: プロジェクトチャットでも両タブから送信できる" do
    sign_in_via_business_form
    use_mobile_viewport
    visit business_project_path(project)

    press(find(".business-stamp-picker .stamp-picker__toggle"))
    press(tab("動物"))
    accept_confirm { press(find("button[aria-label='了解！スタンプを送信']")) }
    expect(page).to have_text("送信しました")
    expect(ProjectChat.last.stamp_type).to eq "animal_got_it"

    press(find(".business-stamp-picker .stamp-picker__toggle"))
    expect(selected_tab_label).to eq "シンプル"
    accept_confirm { press(find("button[aria-label='OKスタンプを送信']")) }
    expect(page).to have_text("送信しました")
    expect(ProjectChat.last.stamp_type).to eq "ok"
    expect(page).to have_css(".business-chat-stamp img[alt='OK']")
    expect(horizontal_overflow).to be <= 0
  end
end
