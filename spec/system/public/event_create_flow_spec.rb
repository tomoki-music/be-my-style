require "rails_helper"

RSpec.describe "イベント新規作成の正規フロー", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:manager) { create(:customer, is_owner: :community_owner) }
  let!(:managed) { create(:community, name: "自分のコミュニティ", owner_id: manager.id) }
  let!(:unmanaged) { create(:community, name: "他人のコミュニティ", owner_id: create(:customer).id) }

  before do
    CommunityOwner.create!(customer: manager, community: managed)
    visit new_customer_session_path
    fill_in "customer_email", with: manager.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def set_datetime(name, time)
    page.execute_script(
      "document.querySelector(arguments[0]).value = arguments[1]",
      "input[name='event[#{name}]']",
      time.strftime("%Y-%m-%dT%H:%M")
    )
  end

  def fill_and_submit
    fill_in "event[event_name]", with: "画面から作成"
    set_datetime("event_start_time", 30.days.from_now)
    set_datetime("event_end_time", 30.days.from_now + 2.hours)
    set_datetime("event_entry_deadline", 20.days.from_now)
    fill_in "event[entrance_fee]", with: "1000"
    fill_in "event[place]", with: "スタジオ"
    fill_in "event[address]", with: "埼玉県さいたま市"
    first("input[name*='[song_name]']").set("曲名")
    accept_confirm { click_button "イベントを登録" }
    expect(page).to have_content("イベントを投稿しました", wait: 15)
  end

  it "コミュニティの画面から開いた新規作成で、そのコミュニティを主催に作成できる" do
    visit new_public_event_path(community_id: managed.id)
    expect(page).to have_content("自分のコミュニティ")

    fill_and_submit

    expect(Event.find_by!(event_name: "画面から作成").community).to eq managed
  end

  it "セレクトには権限のあるコミュニティだけが出て、選んだコミュニティを主催に作成できる" do
    visit new_public_event_path

    select_box = find("select[name='event[community_id]']")
    expect(select_box).to have_content("自分のコミュニティ")
    expect(select_box).not_to have_content("他人のコミュニティ")
    select_box.select("自分のコミュニティ")

    fill_and_submit

    expect(Event.find_by!(event_name: "画面から作成").community).to eq managed
  end

  it "コピー画面の実際のフォームから保存すると、コピー元の主催で作成され、プレビューも同じ主催で動く" do
    source = create(:event, :event_with_songs,
      customer: manager, community: managed, event_name: "コピー元",
      event_start_time: 30.days.from_now, event_end_time: 30.days.from_now + 2.hours, event_entry_deadline: 20.days.from_now)

    visit copy_public_event_path(source)
    page.execute_script(<<~JS)
      window.__previewStatuses = [];
      const originalFetch = window.fetch;
      window.fetch = function (url) {
        const result = originalFetch.apply(this, arguments);
        if (String(url).includes("deadline_reminder_preview")) {
          result.then(function (response) { window.__previewStatuses.push(response.status); });
        }
        return result;
      };
    JS
    reminder_checkbox = first("input[type=checkbox][name*='deadline_reminders_attributes'][name*='enabled']", visible: :all)
    page.execute_script("arguments[0].click()", reminder_checkbox)
    expect(page).to have_css(".deadline-reminder-settings", wait: 10)
    Timeout.timeout(10) { sleep 0.1 until page.evaluate_script("window.__previewStatuses.length").positive? }
    expect(page.evaluate_script("window.__previewStatuses")).to all(eq(200))

    accept_confirm { click_button "イベントを登録" }
    expect(page).to have_content("イベントを投稿しました", wait: 15)

    created = Event.find_by!(event_name: "コピー元（コピー）")
    expect(created.community).to eq managed
    expect(created.customer).to eq manager
  end
end
