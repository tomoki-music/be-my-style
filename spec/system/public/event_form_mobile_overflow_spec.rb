require "rails_helper"

# イベント編集・新規作成画面(公開側)で、スマートフォン幅表示時にページ全体が
# 横スクロールしてしまう不具合の回帰防止テスト。
#
# 原因: .event-table(table-layout: auto)に、
#   - file_field(ブラウザ既定の「ファイルを選択」ボタンが縮まない)
#   - datetime_field/number_fieldへのインラインstyle="width:260px"
#   - JS(events/form.js)が画像選択時に挿入する.new-img(固定300px)
# など「セル幅より縮まないコンテンツ」が含まれており、table-layout: autoの
# 自動列幅計算がその実測幅(min-content)を採用してテーブル全体を90%指定より
# 広げてしまい、画面幅を超えていた(events.scssのtable-layout: fixed対応で修正)。
#
# 実機/実ブラウザが使えないため、selenium_chrome_headless + CDPの
# Emulation.setDeviceMetricsOverrideで実際のモバイル幅を再現して検証する。
# 注記: page.current_window.resize_to(width, height)は、この環境のheadless
# Chromeでは最小ウィンドウ幅(500px程度)に丸められてしまい320〜414pxを再現できない
# (event_request_youtube_card_spec.rbの既存コメントで報告済みの同一環境制約)。
# CDPのデバイスメトリクス上書きはこの制約を受けずに再現できることを確認済み。
RSpec.describe "イベント編集・新規作成画面のモバイル横スクロール", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:owner) { create(:customer) }
  let(:community) { create(:community) }
  let(:event) { create(:event, :event_with_songs, customer: owner, community: community) }

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def set_mobile_viewport(width, height = 812)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 2, mobile: true
    )
  end

  # このアプリには本仕様と無関係な既存のグローバルオーバーフロー
  # (ヘッダーのスマホ用メニュー .customer-menu-sp 等、320px幅でのみ約6px)が
  # 元々存在する(イベント画面に限らずどのページでも発生することを確認済み)。
  # 本specの対象はあくまで.event-table回りなので、ページ全体のscrollWidthを
  # 無関係ページのベースラインと比較し、「イベントフォームが追加の横スクロールを
  # 発生させていないこと」を検証する(ゼロオーバーフローの断定はしない)。
  def baseline_scroll_width
    visit public_events_path
    page.evaluate_script("document.documentElement.scrollWidth")
  end

  # .event-table自身と、その中の全input/select/textareaが画面幅内に
  # 収まっていること(はみ出し無し)を検証する。
  def expect_event_table_within_viewport(client_width)
    overflow = page.evaluate_script(<<~JS)
      (function () {
        var table = document.querySelector('table.event-table');
        if (!table) return null;
        var clientWidth = document.documentElement.clientWidth;
        var maxRight = table.getBoundingClientRect().right;
        table.querySelectorAll('input, select, textarea, img.new-img').forEach(function (el) {
          var right = el.getBoundingClientRect().right;
          if (right > maxRight) maxRight = right;
        });
        return maxRight - clientWidth;
      })()
    JS
    expect(overflow).to be <= 1 # サブピクセル誤差許容
  end

  context "編集画面" do
    before do
      CommunityOwner.find_or_create_by!(customer: owner, community: community)
      CommunityCustomer.find_or_create_by!(customer: owner, community: community)
      sign_in_via_form(owner)
    end

    [320, 375, 390, 414].each do |width|
      it "#{width}px幅で.event-tableが画面外にはみ出さないこと" do
        set_mobile_viewport(width)
        baseline = baseline_scroll_width

        visit edit_public_event_path(event)

        client_width = page.evaluate_script("document.documentElement.clientWidth")
        scroll_width = page.evaluate_script("document.documentElement.scrollWidth")

        expect(scroll_width).to be <= baseline
        expect_event_table_within_viewport(client_width)
      end
    end

    it "375px幅で「曲を追加」した後も横スクロールが増えないこと" do
      set_mobile_viewport(375)
      baseline = baseline_scroll_width

      visit edit_public_event_path(event)

      songs_before = page.all(".song-layout").count
      # CDPのmobile:trueオーバーライドでタッチ入力扱いになり、ネイティブ座標クリックが
      # 固定ヘッダー等に取りこぼされることがある(song_templates_spec.rbの既存コメントと
      # 同じ既知の制約)ため、クリックはJS実行で行う。
      page.execute_script("document.querySelector('.js-add-song-field-btn').click()")
      expect(page).to have_selector(".song-layout", count: songs_before + 1, wait: 10)

      client_width = page.evaluate_script("document.documentElement.clientWidth")
      scroll_width = page.evaluate_script("document.documentElement.scrollWidth")

      expect(scroll_width).to be <= baseline
      expect_event_table_within_viewport(client_width)
    end

    it "375px幅で画像プレビュー(.new-img)表示後も横スクロールが増えないこと" do
      set_mobile_viewport(375)
      baseline = baseline_scroll_width

      visit edit_public_event_path(event)

      attach_file("event_event_image", Rails.root.join("spec/fixtures/thread_sample_image.png"), make_visible: true)
      expect(page).to have_css(".new-img")

      client_width = page.evaluate_script("document.documentElement.clientWidth")
      scroll_width = page.evaluate_script("document.documentElement.scrollWidth")

      expect(scroll_width).to be <= baseline
      expect_event_table_within_viewport(client_width)
    end

    it "既存の曲・パートが多数ある編集画面でも375px幅で横スクロールが増えないこと" do
      3.times { create(:song, event: event) }
      event.songs.each do |song|
        %w[Vocal Guitar Bass].each { |part| song.join_parts.create!(join_part_name: part) }
      end

      set_mobile_viewport(375)
      baseline = baseline_scroll_width

      visit edit_public_event_path(event)

      client_width = page.evaluate_script("document.documentElement.clientWidth")
      scroll_width = page.evaluate_script("document.documentElement.scrollWidth")

      expect(scroll_width).to be <= baseline
      expect_event_table_within_viewport(client_width)
    end

    it "バリデーションエラーで再表示された編集画面でも375px幅で横スクロールが増えないこと" do
      set_mobile_viewport(375)
      baseline = baseline_scroll_width

      visit edit_public_event_path(event)

      fill_in "event_event_name", with: ""
      page.execute_script("window.confirm = function() { return true; };")
      click_button "イベントを登録"

      expect(page).to have_css(".event-edit-title .alert")

      client_width = page.evaluate_script("document.documentElement.clientWidth")
      scroll_width = page.evaluate_script("document.documentElement.scrollWidth")

      expect(scroll_width).to be <= baseline
      expect_event_table_within_viewport(client_width)
    end

    it "1280px幅(PC相当)ではtable-layout: fixedの制約が適用されず横幅に余裕があること" do
      set_mobile_viewport(1280, 900)
      visit edit_public_event_path(event)

      table_layout = page.evaluate_script(
        "getComputedStyle(document.querySelector('table.event-table')).tableLayout"
      )
      table_width = page.evaluate_script(
        "document.querySelector('table.event-table').getBoundingClientRect().width"
      )

      expect(table_layout).to eq("auto")
      expect(table_width).to be > 700
    end
  end

  context "新規作成画面" do
    before do
      CommunityOwner.find_or_create_by!(customer: owner, community: community)
      CommunityCustomer.find_or_create_by!(customer: owner, community: community)
      sign_in_via_form(owner)
    end

    it "375px幅で.event-table(共通partial)が画面外にはみ出さないこと" do
      set_mobile_viewport(375)
      baseline = baseline_scroll_width

      visit new_public_event_path(community_id: community.id)

      client_width = page.evaluate_script("document.documentElement.clientWidth")
      scroll_width = page.evaluate_script("document.documentElement.scrollWidth")

      expect(scroll_width).to be <= baseline
      expect_event_table_within_viewport(client_width)
    end
  end
end
