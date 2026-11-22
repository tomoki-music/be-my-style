require "rails_helper"

# 本人のマイページから通知設定を開き、現在値の表示・保存・再読み込み後の反映を PC 幅とスマホ幅のブラウザで確認する。
RSpec.describe "Business 通知設定の画面", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:me) { create(:customer, name: "通知設定を試す人", domain_name: "business", onboarding_done: true, confirm_mail: true) }

  def sign_in_via_business_form(customer)
    visit new_business_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_current_path(business_root_path, wait: 10)
  end

  def statuses
    all(".notification-settings__status strong").map(&:text)
  end

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  def screenshot(name)
    dir = ENV["NOTIFICATION_SETTINGS_SCREENSHOT_DIR"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir.present?
  end

  { "スマホ" => -> { use_mobile_viewport }, "PC" => -> { use_desktop_viewport } }.each do |label, viewport|
    it "#{label}: マイページから開いて保存し、再読み込み後も反映されている" do
      sign_in_via_business_form(me)
      instance_exec(&viewport)

      visit business_customer_path(me)
      within(".ba-user__action") { click_link "通知設定" }

      expect(page).to have_current_path(business_notification_setting_path)
      expect(page).to have_text("この設定の対象は NAKAMA の通知だけです。")
      expect(statuses).to eq %w[オン オン]
      expect(page).to have_checked_field("メールで受け取る")
      expect(page).to have_checked_field("ベル・通知一覧に表示する")
      expect(horizontal_overflow).to be <= 0
      screenshot("#{label}-1-before")

      uncheck "メールで受け取る"
      click_button "保存する"

      expect(page).to have_text("通知設定を保存しました")
      expect(statuses).to eq %w[オフ オン]
      screenshot("#{label}-2-saved")

      page.refresh

      expect(page).to have_unchecked_field("メールで受け取る")
      expect(page).to have_checked_field("ベル・通知一覧に表示する")
      expect(statuses).to eq %w[オフ オン]
      expect(horizontal_overflow).to be <= 0
      screenshot("#{label}-3-reloaded")
      expect(me.reload.confirm_mail).to eq true
    end
  end
end
