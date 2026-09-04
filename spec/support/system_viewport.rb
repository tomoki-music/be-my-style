# System spec のビューポート(表示幅)制御を1箇所に集約する。
#
# 背景 / なぜこのファイルが必要か:
#   - この環境の headless Chrome では
#       page.driver.browser.manage.window.resize_to(w, h)
#     が最小ウィンドウ幅(約500px)へ丸められ、スマートフォン幅を再現できない
#     (event_form_mobile_overflow_spec.rb 等の既存コメントで報告済み)。
#     さらに resize_to は innerWidth ではなく OS ウィンドウサイズしか変えないため、
#     CSS のメディアクエリ判定に使われる window.innerWidth を確実に動かせない。
#   - そのため各 spec は CDP の Emulation.setDeviceMetricsOverride で
#     innerWidth を直接上書きしている。これはブラウザ(CDP セッション)レベルの
#     上書きで、Capybara.reset_sessions! でも解除されない。
#   - 解除しないと、直前の example がセットしたスマホ/PC 幅のまま次の example が
#     走り、実行順(config.order = :random)によって結果が変わる。
#     PR #184(CI への ImageMagick 導入)で表面化した
#     chat_thread_image_size_spec.rb の「PC 幅なのに 120px になる」順序依存は
#     これが原因(先行する chat_room_sidebar_image_spec.rb が幅390で終了 →
#     override が残存 → 後続の PC example が 391px で描画)。
#
# 方針:
#   1. ビューポート変更は CDP override 方式に統一したヘルパーで行う。
#   2. 変更後は固定 sleep ではなく、実際の window.innerWidth が目標ブレークポイントの
#      十分内側に入ったことを状態ベースで確認する。
#   3. 各 system example の終了時に override を必ず解除し、次の example へ漏らさない
#      (example が失敗・例外終了しても after フックは走る)。

require "selenium/webdriver"

module SystemViewport
  # 目標ビューポート。対象ブレークポイント
  #   - チャット添付画像: @media (max-width: 600px)  (public/chat_messages.scss)
  #   - ヘッダー等の PC 切替: min-width: 768px
  # から十分離した値にする。
  DESKTOP = { width: 1280, height: 900 }.freeze
  MOBILE  = { width: 390,  height: 844 }.freeze

  # 適用後の window.innerWidth がこの範囲に入っていることを確認する。
  DESKTOP_MIN_INNER_WIDTH = 1024
  MOBILE_MAX_INNER_WIDTH  = 600

  def use_desktop_viewport(width: DESKTOP[:width], height: DESKTOP[:height])
    apply_device_metrics(width: width, height: height, mobile: false)
    assert_inner_width("desktop (>= #{DESKTOP_MIN_INNER_WIDTH}px)") { |w| w >= DESKTOP_MIN_INNER_WIDTH }
  end

  def use_mobile_viewport(width: MOBILE[:width], height: MOBILE[:height])
    apply_device_metrics(width: width, height: height, mobile: true)
    assert_inner_width("mobile (<= #{MOBILE_MAX_INNER_WIDTH}px)") { |w| w <= MOBILE_MAX_INNER_WIDTH }
  end

  # 直前の example が残した CDP override を解除する。system spec の after フックから呼ぶ。
  def reset_viewport_override
    return unless cdp_capable_browser_started?

    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  rescue Selenium::WebDriver::Error::WebDriverError
    # ブラウザ / セッションが既に終了しているケースのみ握りつぶす。
    # 次の example は新しいセッションになるため実害はなく、
    # example 本来の失敗をこの teardown で上書きしないようにする。
  end

  private

  # rack_test / Firefox など CDP 非対応 driver、およびブラウザ未起動の example では
  # 何もしない。@browser を直接参照して判定する(page.driver.browser を呼ぶと
  # cleanup のためだけにブラウザを起動してしまうため)。
  def cdp_capable_browser_started?
    driver = page.driver
    return false unless driver.is_a?(Capybara::Selenium::Driver)
    return false unless driver.instance_variable_defined?(:@browser)

    browser = driver.instance_variable_get(:@browser)
    browser.respond_to?(:execute_cdp)
  end

  def apply_device_metrics(width:, height:, mobile:)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: mobile
    )
  end

  # setDeviceMetricsOverride は CDP コマンドの応答が返った時点で適用済みで、
  # 直後の window.innerWidth に同期的に反映される(レイアウト/描画の待ちは不要)。
  # 固定 sleep やリトライは足さず、実際の innerWidth が目標レンジに入ったことを
  # その場で1回検証し、外れていれば即失敗させる(順序依存や適用漏れを早期に顕在化させる)。
  def assert_inner_width(label)
    actual = page.evaluate_script("window.innerWidth").to_i
    return actual if yield(actual)

    raise "ビューポート #{label} を適用できませんでした (window.innerWidth=#{actual})"
  end
end

RSpec.configure do |config|
  config.include SystemViewport, type: :system

  config.after(:each, type: :system) do
    reset_viewport_override
  end
end
