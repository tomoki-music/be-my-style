require "rails_helper"

# 運営プリセットのイラストスタンプを、リクエスト(イベント)とチャットの両方で
# 実ブラウザから選択・送信し、投稿として画像表示されることを検証する。
RSpec.describe "イラストスタンプ", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer, :customer_with_parts) }
  let(:other_customer) { create(:customer, :customer_with_parts) }
  let(:community) { create(:community) }

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  # data-confirm を常に承認し、対象要素へ直接クリックイベントを発火させる
  # (headless Chrome でのネイティブ confirm / 座標クリック取りこぼし対策。
  #  既存の chat_event_link_preview_spec.rb 等と同じ方針)。
  def tap_stamp(picker_selector, stamp_key, tab: nil)
    page.execute_script("window.confirm = function () { return true; };")
    page.execute_script(<<~JS)
      (function () {
        var picker = document.querySelector(#{picker_selector.to_json});
        picker.querySelector('[data-stamp-picker-toggle]').click();
        var tab = #{tab.to_json};
        if (tab) picker.querySelector('[data-stamp-tab="' + tab + '"]').click();
        var input = picker.querySelector('input[value="#{stamp_key}"]');
        input.closest('form').querySelector('.stamp-choice').click();
      })();
    JS
  end

  # ピッカーを開いた直後に表示されているタブパネルの category を返す。
  def visible_tab_category(picker_selector)
    page.execute_script(<<~JS)
      var picker = document.querySelector(#{picker_selector.to_json});
      picker.querySelector('[data-stamp-picker-toggle]').click();
      var visible = Array.prototype.filter.call(
        picker.querySelectorAll('[data-stamp-tabpanel]'),
        function (p) { return !p.hidden; }
      );
      return visible.map(function (p) { return p.getAttribute('data-stamp-tabpanel'); }).join(',');
    JS
  end

  describe "リクエスト(イベント)" do
    let(:event) { create(:event, :event_with_songs, customer: customer, community: community) }

    before do
      customer.update!(onboarding_done: true)
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
      sign_in_via_form(customer)
    end

    it "スタンプボタンでパネルを開き、選んだシンプルスタンプが画像付きで投稿されること" do
      visit public_event_path(event)

      toggle = find("[data-stamp-picker-toggle]", match: :first)
      expect(toggle).to have_content("スタンプ")
      expect(page).to have_css("[data-stamp-picker-panel]", visible: :hidden)

      expect(visible_tab_category(".stamp-picker-field")).to eq "simple"

      tap_stamp(".stamp-picker-field", "wonderful")

      expect(page).to have_css("#event-request-asy img.stamp-illustration[alt='素敵']", wait: 10)
      expect(Request.last.stamp_type).to eq "wonderful"
    end

    it "人物タブへ切り替えて選んだPNGスタンプが画像付きで投稿されること" do
      visit public_event_path(event)

      tap_stamp(".stamp-picker-field", "character_recommend", tab: "human")

      expect(page).to have_css("#event-request-asy img.stamp-illustration[alt='おすすめ']", wait: 10)
      expect(Request.last.stamp_type).to eq "character_recommend"
    end
  end

  describe "チャット(DM)" do
    let(:chat_room) { create(:chat_room) }

    before do
      create(:chat_room_customer, chat_room: chat_room, customer: customer)
      create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
      sign_in_via_form(customer)
    end

    it "シンプルスタンプを選ぶと吹き出しに画像で表示されること" do
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      tap_stamp(".stamp-picker-field", "see_you")

      expect(page).to have_css(".self-content img.stamp-illustration[alt='また！']", wait: 10)
      expect(ChatMessage.last.stamp_type).to eq "see_you"
    end

    it "どうぶつタブへ切り替えて選んだPNGスタンプが吹き出しに画像で表示されること" do
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      tap_stamp(".stamp-picker-field", "animal_yay", tab: "animal")

      expect(page).to have_css(".self-content img.stamp-illustration[alt='わーい！']", wait: 10)
      expect(ChatMessage.last.stamp_type).to eq "animal_yay"
    end
  end
end
