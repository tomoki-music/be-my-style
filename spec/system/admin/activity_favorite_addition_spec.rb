require "rails_helper"

# 管理画面の活動報告一覧「いいねを追加」の送信前確認(admin_activity_favorite_addition.js)。
RSpec.describe "管理画面の活動報告へのいいね追加(画面)", type: :system do
  before { driven_by :selenium_chrome_headless }

  before { create_owned_favorite_customers }

  let!(:author) { create(:customer) }
  let!(:activity) { create(:activity, customer: author, title: "対象の報告") }
  let(:admin) { create(:admin) }
  # Admin 配下は Customer のログインも必要(既存の挙動)。
  let(:operator) { create(:customer) }

  before do
    visit new_customer_session_path
    fill_in "customer_email", with: operator.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
    visit new_admin_session_path
    fill_in "admin_email", with: admin.email
    fill_in "admin_password", with: "admin-password"
    click_button "管理者としてログイン"
    expect(page).to have_content("管理者ダッシュボード", wait: 10)
    visit admin_activities_path
  end

  it "確認で記事と件数を示し、キャンセルなら追加しない・OKなら追加する" do
    row = find("#admin-activity-#{activity.id}")
    row.select "3", from: "count_#{activity.id}"

    message = dismiss_confirm { row.click_button "いいねを追加" }
    expect(message).to include("活動報告 ID #{activity.id}「対象の報告」に、いいねを3件追加します")
    expect(activity.favorites.count).to eq(0)

    accept_confirm { row.click_button "いいねを追加" }
    expect(page).to have_content("いいねを3件追加しました")
    expect(activity.favorites.pluck(:customer_id)).to match_array([2, 3, 4])
    expect(find("#admin-activity-#{activity.id}").all("td")[4].text).to eq("3")
  end
end
