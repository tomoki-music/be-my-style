require "rails_helper"

# チャットルーム右側の詳細パネル(.partner-container)に表示される大きな画像
# (個別チャット=相手のプロフィール画像 / コミュニティチャット=コミュニティ画像)の
# レイアウト回帰防止テスト。
#
# spec/system/public/customer_song_part_mobile_overflow_spec.rb と同じ手法
# (selenium_chrome_headless + CDP の Emulation.setDeviceMetricsOverride)で、
# PC 幅とスマホ幅を再現し、
#   - 画像が詳細パネルの枠からはみ出さないこと
#   - 元画像の縦横比(縦長 / 横長 / 正方形)によって表示サイズが変わらないこと
#   - 画像が名前(.card-title)へ重ならないこと
#   - スマホ幅で横スクロールが発生しないこと
# を検証する。
RSpec.describe "チャットルーム右側詳細パネルの画像レイアウト", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer) }
  let(:partner) { create(:customer, name: "アーティストABCDEFGHIJKLMN") }
  let(:community) { create(:community) }
  let(:chat_room) { create(:chat_room) }

  let(:tall_image) { Rails.root.join("spec/fixtures/chat_sidebar_tall_sample.png") }
  let(:wide_image) { Rails.root.join("spec/fixtures/chat_sidebar_wide_sample.png") }
  let(:square_image) { Rails.root.join("spec/fixtures/thread_sample_image.png") }

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def set_viewport(width, height = 900)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: width < 768
    )
  end

  # .partner-container 内の画像の描画矩形と、枠・名前との位置関係を返す。
  def sidebar_image_metrics
    page.evaluate_script(<<~JS)
      (function () {
        var frame = document.querySelector('.partner-container .img-container');
        var img = document.querySelector('.partner-container .img-container img');
        var title = document.querySelector('.partner-container .text-container .card-title');
        if (!frame || !img || !title) return null;
        var f = frame.getBoundingClientRect();
        var i = img.getBoundingClientRect();
        var t = title.getBoundingClientRect();
        return {
          docOverflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
          imgRight: i.right, imgBottom: i.bottom,
          frameRight: f.right, frameBottom: f.bottom,
          titleTop: t.top,
          imgWidth: i.width, imgHeight: i.height
        };
      })()
    JS
  end

  def expect_image_contained(m)
    expect(m).not_to be_nil
    # 画像が枠からはみ出さない(サブピクセル誤差許容)。
    expect(m["imgRight"]).to be <= m["frameRight"] + 1
    expect(m["imgBottom"]).to be <= m["frameBottom"] + 1
    # 画像が名前へ重ならない(名前は画像の下の通常フローにある)。
    expect(m["titleTop"]).to be >= m["imgBottom"] - 1
    # 横スクロールが発生しない。
    expect(m["docOverflow"]).to be <= 1
  end

  describe "個別チャット右側パネルの相手プロフィール画像" do
    before do
      create(:chat_room_customer, chat_room: chat_room, customer: customer)
      create(:chat_room_customer, chat_room: chat_room, customer: partner)
    end

    [
      ["縦長画像", :tall_image],
      ["横長画像", :wide_image],
      ["正方形画像", :square_image]
    ].each do |label, image_ref|
      [1280, 390].each do |width|
        it "#{label} / 幅#{width}px でも枠に収まり名前へ重ならないこと" do
          partner.profile_image.attach(io: File.open(send(image_ref)), filename: "avatar.png", content_type: "image/png")

          sign_in_via_form(customer)
          set_viewport(width)
          visit public_chat_room_path(chat_room, customer_id: partner.id)

          expect(page).to have_selector(".partner-container .img-container img")
          expect_image_contained(sidebar_image_metrics)
        end
      end
    end

    it "画像の縦横比が違っても表示サイズが一定であること" do
      sign_in_via_form(customer)
      set_viewport(1280)

      sizes = %i[tall_image wide_image square_image].map do |image_ref|
        partner.profile_image.attach(io: File.open(send(image_ref)), filename: "avatar.png", content_type: "image/png")
        visit public_chat_room_path(chat_room, customer_id: partner.id)
        expect(page).to have_selector(".partner-container .img-container img")
        m = sidebar_image_metrics
        [m["imgWidth"].round, m["imgHeight"].round]
      end

      expect(sizes.uniq.size).to eq(1)
    end
  end

  describe "コミュニティチャット右側パネルのコミュニティ画像" do
    let(:community_chat_room) { create(:chat_room) }

    before do
      create(:chat_room_customer, chat_room: community_chat_room, customer: customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
    end

    [
      ["縦長画像", :tall_image],
      ["横長画像", :wide_image],
      ["画像未登録", nil]
    ].each do |label, image_ref|
      [1280, 390].each do |width|
        it "#{label} / 幅#{width}px でも枠に収まり名前へ重ならないこと" do
          if image_ref
            community.community_image.attach(io: File.open(send(image_ref)), filename: "community.png", content_type: "image/png")
          end

          sign_in_via_form(customer)
          set_viewport(width)
          visit community_show_public_chat_rooms_path(community_chat_room)

          expect(page).to have_selector(".partner-container .img-container img.chat-partner-community-image")
          expect_image_contained(sidebar_image_metrics)
        end
      end
    end
  end
end
