require "rails_helper"

# 画像の表示位置の調整を、実際のブラウザで確認する。PC はマウスのドラッグ、スマホ幅は指のスライド(タッチ)。
# 新しい画像を選んで位置を決めて保存 → 編集画面を開き直すと位置が戻る → 画像はそのままで位置だけ変える、の流れ。
RSpec.describe "画像の表示位置の調整", type: :system, js: true do
  include Warden::Test::Helpers

  FIXTURE_DIR = Rails.root.join("spec/fixtures/files/image_position")
  SCREENSHOT_DIR = ENV["IMAGE_POSITION_SCREENSHOT_DIR"]

  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }

  after do
    Warden.test_reset!
    # タッチ入力の有効化はブラウザ単位で残るため、後続の spec へ持ち越さない。
    page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  rescue Selenium::WebDriver::Error::WebDriverError
    nil
  end

  def frames
    all("[data-image-position-frame]", minimum: 1)
  end

  # 指定した向きにはみ出している(=その向きに動かせる)最初の枠。
  def draggable_frame_index(axis)
    page.evaluate_script(<<~JS)
      (function () {
        var frames = Array.prototype.slice.call(document.querySelectorAll("[data-image-position-frame]"));
        return frames.findIndex(function (frame) {
          var img = frame.querySelector("img");
          if (!img.naturalWidth) return false;
          var scale = Math.max(frame.clientWidth / img.naturalWidth, frame.clientHeight / img.naturalHeight);
          var overflow = #{axis == :x ? 'img.naturalWidth * scale - frame.clientWidth' : 'img.naturalHeight * scale - frame.clientHeight'};
          return overflow > 10;
        });
      })()
    JS
  end

  def wait_for_preview_loaded
    expect(page).to have_selector("[data-image-position-editor]:not([hidden])", wait: 10)
    Timeout.timeout(10) do
      sleep 0.05 until page.evaluate_script(%(Array.prototype.every.call(document.querySelectorAll("[data-image-position-image]"), function (img) { return img.complete && img.naturalWidth > 0; })))
    end
  end

  def mouse_drag(index, dx, dy)
    element = frames[index]
    element.scroll_to(element, align: :center)
    page.driver.browser.action.move_to(element.native).click_and_hold.move_by(dx, dy).release.perform
  end

  # タッチ座標は画面上の位置で指定する。既存の共通ヘッダー(.customer-menu-sp)が横にはみ出すページでは
  # スマホ表示全体が縮小されるため、ページ上の位置に縮小率を掛けて換算する。
  def touch_drag(index, dx, dy)
    frames[index].scroll_to(frames[index], align: :center)
    geometry = page.evaluate_script(<<~JS)
      (function () {
        var rect = document.querySelectorAll("[data-image-position-frame]")[#{index}].getBoundingClientRect();
        var viewport = window.visualViewport || { scale: 1, offsetLeft: 0, offsetTop: 0 };
        return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2, innerWidth: window.innerWidth,
                 scale: viewport.scale, left: viewport.offsetLeft, top: viewport.offsetTop };
      })()
    JS
    # 画面(390px)より広く描画されたときは、エミュレーション側で全体が縮小されている。
    scale = geometry["scale"].to_f * [SystemViewport::MOBILE[:width].to_f / geometry["innerWidth"], 1.0].min
    x = (geometry["x"] - geometry["left"]) * scale
    y = (geometry["y"] - geometry["top"]) * scale
    cdp = page.driver.browser
    cdp.execute_cdp("Input.dispatchTouchEvent", type: "touchStart", touchPoints: [{ x: x, y: y }])
    5.times do |step|
      ratio = (step + 1) / 5.0
      cdp.execute_cdp("Input.dispatchTouchEvent", type: "touchMove", touchPoints: [{ x: x + dx * scale * ratio, y: y + dy * scale * ratio }])
    end
    cdp.execute_cdp("Input.dispatchTouchEvent", type: "touchEnd", touchPoints: [])
  end

  def drag(device, index, dx, dy)
    device == :mobile ? touch_drag(index, dx, dy) : mouse_drag(index, dx, dy)
  end

  def hidden_value(axis)
    find("[data-image-position-#{axis}]", visible: false).value
  end

  def preview_positions
    page.evaluate_script(%(Array.prototype.map.call(document.querySelectorAll("[data-image-position-image]"), function (img) { return getComputedStyle(img).objectPosition; })))
  end

  def computed_position(selector)
    page.evaluate_script(%(getComputedStyle(document.querySelector(#{selector.to_json})).objectPosition))
  end

  def screenshot(name)
    return if SCREENSHOT_DIR.blank?

    FileUtils.mkdir_p(SCREENSHOT_DIR)
    page.save_screenshot(File.join(SCREENSHOT_DIR, "#{name}.png"))
  end

  # 音楽側の保存ボタンは確認ダイアログを出すので、承認した扱いにして送信する。
  def submit_form(button)
    page.execute_script("window.confirm = function () { return true; };")
    # 縮小表示されたページでは座標クリックがずれるため、ボタン要素を直接押す。
    page.execute_script("arguments[0].click();", find_button(button))
  end

  # 対象ごとの画面。axis_image: 縦長(tall)は縦に、横長(wide)は横に動かせる。
  TARGETS = {
    "Business コミュニティ" => {
      edit: ->(ctx) { ctx.edit_business_community_path(ctx.community) },
      show: ->(ctx) { ctx.business_community_path(ctx.community) },
      display: ".ba-profile__cover-image",
      record: ->(ctx) { ctx.community.reload },
      attribute: :community_image,
      button: "保存する",
      login: :business_owner
    },
    "Business プロジェクト" => {
      edit: ->(ctx) { ctx.edit_business_project_path(ctx.project) },
      show: ->(ctx) { ctx.business_project_path(ctx.project) },
      display: ".ba-profile__cover-image",
      record: ->(ctx) { ctx.project.reload },
      attribute: :project_image,
      button: "保存する",
      login: :business_owner
    },
    "Business プロフィール" => {
      edit: ->(ctx) { ctx.edit_business_customer_path(ctx.business_owner) },
      show: ->(ctx) { ctx.business_customer_path(ctx.business_owner) },
      display: ".ba-user__avatar img.user-profile-image",
      record: ->(ctx) { ctx.business_owner.reload },
      attribute: :profile_image,
      button: "更新する",
      login: :business_owner
    },
    "音楽 コミュニティ" => {
      edit: ->(ctx) { ctx.edit_public_community_path(ctx.music_community) },
      show: ->(ctx) { ctx.public_community_path(ctx.music_community) },
      display: ".community-show-card .img-container img",
      record: ->(ctx) { ctx.music_community.reload },
      attribute: :community_image,
      button: "保存する",
      login: :music_owner
    },
    "音楽 プロフィール" => {
      edit: ->(ctx) { ctx.edit_public_customer_path(ctx.music_owner) },
      show: ->(ctx) { ctx.public_customer_path(ctx.music_owner) },
      display: ".customer-show-card img.user-profile-image",
      record: ->(ctx) { ctx.music_owner.reload },
      attribute: :profile_image,
      button: "プロフィールを更新",
      login: :music_owner
    }
  }.freeze

  let(:business_owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:community) { create(:community, owner: business_owner, domain: business_domain, name: "位置調整コミュニティ") }
  let(:project) { Project.create!(community: community, customer: business_owner, title: "位置調整プロジェクト", description: "概要") }
  let(:music_owner) { create(:customer, onboarding_done: true) }
  let(:music_community) { create(:community, owner: music_owner, domain: music_domain, name: "音楽の位置調整") }

  before do
    CommunityCustomer.find_or_create_by!(customer: business_owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: music_owner, community: music_community)
  end

  TARGETS.each do |label, target|
    { mobile: "スマホ(タッチ)", desktop: "PC(マウス)" }.each do |device, device_label|
      it "#{label} / #{device_label}: 新しい画像を調整して保存し、開き直すと位置が戻り、位置だけ変更できる" do
        login_as(public_send(target[:login]), scope: :customer)
        visit target[:show].call(self)
        device == :mobile ? use_mobile_viewport : use_desktop_viewport
        # タッチ入力は、ページを開く前に有効にしておかないと最初のタッチを取りこぼすことがある。
        page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: device == :mobile, maxTouchPoints: 1)
        slug = "#{target[:attribute]}_#{label.start_with?('Business') ? 'business' : 'music'}_#{device}"

        # 1. 新しい画像(縦長)を選ぶ → 縦に動かせる枠をドラッグ → 保存
        visit target[:edit].call(self)
        find("[data-image-position-input]").set(FIXTURE_DIR.join("tall.png").to_s)
        wait_for_preview_loaded
        expect(hidden_value(:x)).to eq ""

        index = draggable_frame_index(:y)
        expect(index).to be >= 0
        drag(device, index, 0, 30)
        expect(hidden_value(:x)).to eq "50"
        new_y = hidden_value(:y).to_f
        expect(new_y).to be_between(0, 49)
        expect(preview_positions.uniq).to eq ["50% #{hidden_value(:y)}%"]
        screenshot("#{slug}_1_new_preview")

        submit_form(target[:button])
        expect(page).to have_no_selector("[data-image-position-field]", wait: 10)
        record = target[:record].call(self)
        expect(record.public_send(target[:attribute]).filename.to_s).to eq "tall.png"
        expect(record.public_send("#{target[:attribute]}_position_y").to_f).to be_within(0.01).of(new_y)

        visit target[:show].call(self)
        expect(computed_position(target[:display])).to eq "50% #{record.public_send("#{target[:attribute]}_object_position").split.last}"
        screenshot("#{slug}_2_new_saved")

        # 2. 編集画面を開き直すと前回の位置が戻る → 画像は選び直さず、位置だけ変えて保存
        blob_id = record.public_send(target[:attribute]).blob.id
        visit target[:edit].call(self)
        wait_for_preview_loaded
        expect(find("[data-image-position-status]")).to have_text("前回保存した位置")
        expect(hidden_value(:y).to_f).to be_within(0.01).of(new_y)
        expect(preview_positions.uniq).to eq [record.public_send("#{target[:attribute]}_object_position")]

        # 画像を上へ動かす＝下側を見せる。指・マウスの移動量どおりに画像が動くので、
        # はみ出しの大きい横長の枠では端まで届かないこともある。
        drag(device, draggable_frame_index(:y), 0, -300)
        moved_y = hidden_value(:y)
        expect(moved_y.to_f).to be > new_y
        expect(moved_y.to_f).to be <= 100
        expect(preview_positions.uniq).to eq ["50% #{moved_y}%"]
        screenshot("#{slug}_3_existing_preview")
        submit_form(target[:button])
        expect(page).to have_no_selector("[data-image-position-field]", wait: 10)

        record = target[:record].call(self)
        expect(record.public_send(target[:attribute]).blob.id).to eq blob_id
        expect(record.public_send("#{target[:attribute]}_object_position")).to eq "50% #{moved_y}%"
        visit target[:show].call(self)
        expect(computed_position(target[:display])).to eq "50% #{moved_y}%"
        screenshot("#{slug}_4_existing_saved")
      end
    end
  end

  it "横長の画像は横に動かせ、プレビューと保存後の一覧アイコンが同じ位置になる(Business コミュニティ / PC)" do
    community.community_image.attach(io: File.open(FIXTURE_DIR.join("wide.png")), filename: "wide.png", content_type: "image/png")
    login_as(business_owner, scope: :customer)
    visit business_community_path(community)
    use_desktop_viewport

    visit edit_business_community_path(community)
    wait_for_preview_loaded
    expect(find("[data-image-position-status]")).to have_text("今の表示（中央基準）")

    index = draggable_frame_index(:x)
    expect(index).to be >= 0
    mouse_drag(index, 400, 0)
    expect(hidden_value(:x)).to eq "0"
    preview = preview_positions.uniq
    expect(preview).to eq ["0% 50%"]
    screenshot("community_image_business_wide_preview")

    click_button "保存する"
    expect(page).to have_no_selector("[data-image-position-field]", wait: 10)
    visit business_communities_path
    expect(computed_position("img.ba-avatar")).to eq preview.first
    screenshot("community_image_business_wide_listing")
  end

  { mobile: "スマホ(タッチ)", desktop: "PC(マウス)" }.each do |device, device_label|
    it "音楽 新規登録 / #{device_label}: 選んだ画像の位置を調整して登録すると、登録後のプロフィールに反映される" do
      visit new_customer_registration_path
      device == :mobile ? use_mobile_viewport : use_desktop_viewport
      page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: device == :mobile, maxTouchPoints: 1)
      visit new_customer_registration_path

      expect(page).to have_selector("[data-image-position-editor][hidden]", visible: false)
      fill_in "customer[email]", with: "signup-position-#{device}@example.com"
      fill_in "customer[password]", with: "password"
      fill_in "customer[password_confirmation]", with: "password"
      fill_in "customer[name]", with: "位置#{device}"
      find("[data-image-position-input]").set(FIXTURE_DIR.join("wide.png").to_s)
      wait_for_preview_loaded

      # 横長の画像は正方形・縦長の枠で横に動かせる。右へ動かす＝左側(赤)を見せる。
      drag(device, draggable_frame_index(:x), 40, 0)
      moved_x = hidden_value(:x)
      expect(moved_x.to_f).to be_between(0, 49)
      expect(hidden_value(:y)).to eq "50"
      expect(preview_positions.uniq).to eq ["#{moved_x}% 50%"]
      screenshot("signup_#{device}_1_preview")

      submit_form("登録する")
      expect(page).to have_current_path(verify_path, wait: 10)

      created = Customer.find_by!(email: "signup-position-#{device}@example.com")
      expect(created.profile_image.filename.to_s).to eq "wide.png"
      expect(created.profile_image_object_position).to eq "#{moved_x}% 50%"

      # 確認メールのリンクを開いた状態にしてから、登録したプロフィールを表示する。
      created.confirm
      created.update!(onboarding_done: true) if created.respond_to?(:onboarding_done)
      login_as(created, scope: :customer)
      visit public_customer_path(created)
      expect(computed_position(".customer-show-card img.user-profile-image")).to eq "#{moved_x}% 50%"
      screenshot("signup_#{device}_2_saved")
    end

    it "歌声 プロフィール編集 / #{device_label}: 新しい画像の位置調整と、既存画像の位置だけの変更が保存後の表示に反映される" do
      singer = create(:customer, domain_name: "singing", onboarding_done: true)
      login_as(singer, scope: :customer)
      visit singing_user_path(singer)
      device == :mobile ? use_mobile_viewport : use_desktop_viewport
      page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: device == :mobile, maxTouchPoints: 1)

      visit edit_singing_user_path(singer)
      find("[data-image-position-input]").set(FIXTURE_DIR.join("tall.png").to_s)
      wait_for_preview_loaded
      drag(device, draggable_frame_index(:y), 0, 30)
      new_y = hidden_value(:y)
      expect(new_y.to_f).to be_between(0, 49)
      screenshot("singing_#{device}_1_new_preview")
      submit_form("保存する")
      expect(page).to have_current_path(singing_user_path(singer), wait: 10)
      expect(singer.reload.profile_image_object_position).to eq "50% #{new_y}%"
      expect(computed_position("img.user-profile-image")).to eq "50% #{new_y}%"
      screenshot("singing_#{device}_2_new_saved")

      blob_id = singer.profile_image.blob.id
      visit edit_singing_user_path(singer)
      wait_for_preview_loaded
      expect(find("[data-image-position-status]")).to have_text("前回保存した位置")
      expect(preview_positions.uniq).to eq ["50% #{new_y}%"]
      drag(device, draggable_frame_index(:y), 0, -60)
      moved_y = hidden_value(:y)
      expect(moved_y.to_f).to be > new_y.to_f
      submit_form("保存する")
      expect(page).to have_current_path(singing_user_path(singer), wait: 10)
      expect(singer.reload.profile_image.blob.id).to eq blob_id
      expect(computed_position("img.user-profile-image")).to eq "50% #{moved_y}%"
      expect(computed_position(".singing-nav__avatar, .singing-nav__mobile-avatar")).to eq "50% #{moved_y}%"
      screenshot("singing_#{device}_3_existing_saved")
    end
  end

  it "キーボードの矢印キーでも位置を動かせる" do
    community.community_image.attach(io: File.open(FIXTURE_DIR.join("tall.png")), filename: "tall.png", content_type: "image/png")
    login_as(business_owner, scope: :customer)
    visit edit_business_community_path(community)
    wait_for_preview_loaded

    frames[draggable_frame_index(:y)].send_keys(:arrow_down, :arrow_down)
    expect(hidden_value(:y)).to eq "46"
    frames[draggable_frame_index(:y)].send_keys([:shift, :arrow_up])
    expect(hidden_value(:y)).to eq "56"
  end
end
