require "rails_helper"

# スレッドパネル内の添付画像が実ブラウザ上で意図した表示サイズ(PC:160x120px / モバイル:120x90px)に
# なることを検証する。あわせて、投稿者アバター(.img-element img)がスレッドパネル・通常チャットの
# どちらでも50x50pxに収まること、および li のlist-style-typeがnoneになっている(ブラウザデフォルトの
# 「・」マーカーが出ない)ことも確認する(いずれも.message-container配下に限定されたCSSスコープの再発防止)。
# クラス付与自体は spec/requests/public/chat_thread_spec.rb で検証済みのため、
# ここでは実レンダリング結果(getBoundingClientRect)のみを、代表ケースに絞って確認する
# (ピクセル単位の検証は環境依存で不安定になりやすいため、ケース数を絞ってCIの安定性を優先する)。
RSpec.describe "スレッドパネル添付画像の表示サイズ", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:sample_image_path) { Rails.root.join("spec/fixtures/thread_sample_image.png") }

  before do
    create(:chat_room_customer, chat_room: chat_room, customer: customer)
    create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
    customer.update!(onboarding_done: true)
    other_customer.update!(onboarding_done: true)
  end

  def attach_sample_image(chat_message)
    chat_message.attachments.attach(
      io: File.open(sample_image_path),
      filename: "thread_sample_image.png",
      content_type: "image/png"
    )
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  # Capybaraのネイティブclickはこのボタン(pill型・隣接flex要素あり)に対して
  # クリック座標がずれることがあり不安定なため、JS側で直接clickイベントを発火させる。
  # Selenium駆動のブラウザはexample間で使い回されるため、モバイル幅テストで
  # resize_toした結果が後続のテストへ持ち越されないよう、PC幅を明示的に固定する。
  def use_desktop_viewport
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  def open_thread_panel
    expect(page).to have_selector(".thread-replies-button", wait: 10)
    page.evaluate_script("document.querySelector('.thread-replies-button').click();")
    expect(page).to have_selector("#thread-panel:not([hidden])", wait: 10)
    expect(page).to have_selector("#thread-panel img.message-image--thread", wait: 10)
  end

  def thread_panel_image_rects
    page.evaluate_script(<<~JS)
      [].slice.call(document.querySelectorAll('#thread-panel img')).map(function (img) {
        var r = img.getBoundingClientRect();
        return { className: img.className, width: Math.round(r.width), height: Math.round(r.height) };
      });
    JS
  end

  describe "個別チャット(DM)のスレッド" do
    it "PC幅ではroot・reply添付画像がともに160x120pxで表示されること" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "画像を送ります")
      attach_sample_image(root)
      reply = create(:chat_message, customer: customer, chat_room: chat_room, content: "返信の画像です",
                                     reply_to_chat_message: root)
      attach_sample_image(reply)

      sign_in_via_form(customer)
      use_desktop_viewport
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)
      open_thread_panel

      thread_images = thread_panel_image_rects.select { |img| img["className"].include?("message-image--thread") }
      expect(thread_images.size).to eq(2)
      thread_images.each do |img|
        expect(img["width"]).to eq(160)
        expect(img["height"]).to eq(120)
      end

      avatar_images = thread_panel_image_rects.reject { |img| img["className"].include?("message-image--thread") }
      expect(avatar_images).not_to be_empty
      avatar_images.each do |img|
        expect(img["width"]).to eq(50)
        expect(img["height"]).to eq(50)
      end

      normal_avatar_rects = page.evaluate_script(<<~JS)
        [].slice.call(document.querySelectorAll('.message-container .chat-room-customer-link .img-element img')).map(function (img) {
          var r = img.getBoundingClientRect();
          return { width: Math.round(r.width), height: Math.round(r.height) };
        });
      JS
      expect(normal_avatar_rects).not_to be_empty
      normal_avatar_rects.each do |img|
        expect(img["width"]).to eq(50)
        expect(img["height"]).to eq(50)
      end

      thread_list_style_types = page.evaluate_script(<<~JS)
        [].slice.call(document.querySelectorAll('#thread-panel li')).map(function (li) {
          return getComputedStyle(li).listStyleType;
        });
      JS
      expect(thread_list_style_types).not_to be_empty
      expect(thread_list_style_types.uniq).to eq(["none"])

      normal_list_style_types = page.evaluate_script(<<~JS)
        [].slice.call(document.querySelectorAll('.message-container li')).map(function (li) {
          return getComputedStyle(li).listStyleType;
        });
      JS
      expect(normal_list_style_types).not_to be_empty
      expect(normal_list_style_types.uniq).to eq(["none"])
    end

    it "モバイル幅(600px以下)ではroot添付画像が120x90pxで表示されること" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "画像を送ります")
      attach_sample_image(root)
      create(:chat_message, customer: customer, chat_room: chat_room, content: "返信です",
                             reply_to_chat_message: root)

      sign_in_via_form(customer)
      page.driver.browser.manage.window.resize_to(480, 900)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)
      open_thread_panel

      thread_images = thread_panel_image_rects.select { |img| img["className"].include?("message-image--thread") }
      expect(thread_images.size).to eq(1)
      expect(thread_images.first["width"]).to eq(120)
      expect(thread_images.first["height"]).to eq(90)
    end
  end

  describe "コミュニティチャットのスレッド" do
    it "PC幅ではroot添付画像が160x120pxで表示されること" do
      community = create(:community, owner_id: other_customer.id)
      CommunityCustomer.create!(community: community, customer: customer)
      CommunityCustomer.create!(community: community, customer: other_customer)

      community_room = create(:chat_room)
      ChatRoomCustomer.create!(chat_room: community_room, customer: customer, community_id: community.id)
      ChatRoomCustomer.create!(chat_room: community_room, customer: other_customer, community_id: community.id)

      root = create(:chat_message, customer: other_customer, chat_room: community_room, community: community,
                                    content: "コミュニティに画像を送ります")
      attach_sample_image(root)
      create(:chat_message, customer: customer, chat_room: community_room, community: community, content: "返信です",
                             reply_to_chat_message: root)

      sign_in_via_form(customer)
      use_desktop_viewport
      visit community_show_public_chat_rooms_path(community_room)
      open_thread_panel

      thread_images = thread_panel_image_rects.select { |img| img["className"].include?("message-image--thread") }
      expect(thread_images.size).to eq(1)
      expect(thread_images.first["width"]).to eq(160)
      expect(thread_images.first["height"]).to eq(120)
    end
  end
end
