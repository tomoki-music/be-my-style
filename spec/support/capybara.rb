require "selenium/webdriver"

Capybara.javascript_driver = :selenium_chrome_headless
Capybara.default_max_wait_time = 5 #5秒に設定
Selenium::WebDriver.logger.level = :warn
