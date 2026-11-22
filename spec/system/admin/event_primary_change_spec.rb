require "rails_helper"

RSpec.describe "管理画面のイベント主催コミュニティ変更", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:admin) { create(:admin) }
  let!(:western) { create(:community, name: "洋楽セッション") }
  let!(:jazz) { create(:community, name: "ジャズセッション") }
  let(:event) { create(:event, :event_with_songs, community: western) }

  before do
    visit new_admin_session_path
    fill_in "admin_email", with: admin.email
    fill_in "admin_password", with: "admin-password"
    click_button "管理者としてログイン"
    expect(page).to have_no_current_path(new_admin_session_path, wait: 10)
    visit edit_admin_event_path(event)
  end

  it "主催を選び直すと旧主催が残るかどうかを保存前に表示し、保存後の結果も案内する" do
    preview = ".event-primary-change__preview"
    expect(page).to have_no_css(preview, visible: :visible)

    select "ジャズセッション", from: "event[community_id]"
    expect(find(preview)).to have_text("主催が「ジャズセッション」に変わり、「洋楽セッション」は共催先に残ります。")

    uncheck "event[keep_previous_primary_as_cohost]"
    expect(find(preview)).to have_text("「洋楽セッション」は共催先から外れます。")

    check "event[keep_previous_primary_as_cohost]"
    select "洋楽セッション", from: "event[community_id]"
    expect(page).to have_no_css(preview, visible: :visible)
  end
end
