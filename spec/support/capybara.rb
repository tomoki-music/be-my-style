require "selenium/webdriver"
require "capybara"

Capybara.javascript_driver = :selenium_chrome_headless
Capybara.default_max_wait_time = 5 #5秒に設定
Selenium::WebDriver.logger.level = :warn

# selenium-webdriver 4.32 + 近年の Chrome / chromedriver は、DOM から外れた直後の要素へ
# アクセスすると、本来のリトライ可能な StaleElementReferenceError ではなく
#   Selenium::WebDriver::Error::UnknownError
#   ("unknown error: unhandled inspector error: ... Node with given id does not belong to the document")
# を投げることがある(visible? / visible_text / text / 属性参照など、経路は複数)。
#
# Capybara は synchronize のリトライ判定 catch_error? が真を返す例外だけを「要素を取り直して
# 再評価」する。既定では上記 UnknownError はリトライ対象外なので、
#   - ログイン後のオンボーディングへのリダイレクト(document 差し替え)
#   - 検索 / ピン留めパネルの結果一覧を innerHTML で再描画
#   - リンクカードの描画途中の DOM 変化
# と Capybara の参照解決が競合したとき、本来リトライで解決するはずのケースで example が
# 即失敗する。対象 spec が実行ごとに入れ替わる形のフレーク(pin / search / song_link_preview)の
# 原因がこれだった。
#
# ここでは「切り離されたノード」を表すメッセージ形状に限定して catch_error? を真にし、
# Capybara 本来の待機付きリトライ(要素を取り直して再評価)へ委ねる。固定 sleep・example 単位の
# リトライ・期待値の緩和は使わない。
#
# - リトライ回数・時間は Capybara の synchronize が持つ既存タイマー(default_max_wait_time /
#   matcher の wait:)で頭打ちになり、無限リトライにはならない。待機時間内に要素が安定
#   しなければ、元の UnknownError がそのまま raise されて従来どおり example は失敗する。
# - このファイルは spec/support 配下で rails_helper 経由でのみ読み込まれ、production には載らない。
# - chrome_node.rb が「chromedriver が誤った例外クラスを投げる」ケースを再解釈しているのと同じ方針。
module CapybaraDetachedNodeRetry
  DETACHED_NODE_MESSAGE = /
    node\ with\ given\ id\ does\ not\ belong\ to\ the\ document |
    is\ not\ attached\ to\ the\ (?:page\ )?document |
    node\ is\ detached\ from\ (?:the\ )?document
  /xi

  # Capybara::Node::Base#catch_error? は protected。可視性も元に合わせておく。
  protected

  def catch_error?(error, errors = nil)
    if error.is_a?(::Selenium::WebDriver::Error::WebDriverError) &&
       error.message.to_s.match?(DETACHED_NODE_MESSAGE)
      return true
    end

    super
  end
end

Capybara::Node::Base.prepend(CapybaraDetachedNodeRetry)
