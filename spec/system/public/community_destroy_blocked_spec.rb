require "rails_helper"

RSpec.describe "コミュニティ削除を止めたときの案内ページ", type: :system do
  before { driven_by :selenium_chrome_headless }
  after { reset_viewport_override }

  let(:owner) { create(:customer) }
  let!(:community) { create(:community, name: "洋楽セッション", owner_id: owner.id) }
  let!(:cohost) { create(:community, name: "邦楽セッション", owner_id: owner.id) }

  before do
    21.times do |i|
      create(:event, :event_with_songs, customer: owner, community: community, event_name: "とても長い名前の合同セッション第#{i + 1}回" * 4)
        .update!(selected_cohost_community_ids: [cohost.id])
    end
    visit new_customer_session_path
    fill_in "customer_email", with: owner.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def expect_inside_viewport(selector)
    overflowing = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(#{selector.to_json})).filter(function (element) {
        var rect = element.getBoundingClientRect();
        return rect.left < 0 || rect.right > document.documentElement.clientWidth;
      }).length
    JS
    expect(overflowing).to eq 0
  end

  it "スマホ幅でも理由と全イベントを読めて、次のページへ進み、時間が経っても消えない" do
    use_mobile_viewport
    visit destroy_blocked_public_community_path(community)

    expect(page).to have_content("削除を止めました")
    expect(page).to have_content("先に管理画面で主催を変更します")
    expect(page).to have_css(".community-destroy-blocked__item", count: Community::BLOCKED_EVENTS_PER_PAGE)
    %w[.community-destroy-blocked .community-destroy-blocked__reason .community-destroy-blocked__item .community-destroy-blocked__event-links].each do |selector|
      expect_inside_viewport(selector)
    end
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.community-destroy-blocked__reason')).opacity")).to eq "1"

    within(".community-destroy-blocked") { first("a[href*='page=2']").click }
    expect(page).to have_css(".community-destroy-blocked__item", count: 1, wait: 10)
    expect(page).to have_content("第21回")
    expect_inside_viewport(".community-destroy-blocked__item")

    within(".community-destroy-blocked") { click_link "イベント詳細" }
    expect(page).to have_current_path(%r{/public/events/\d+}, wait: 10)
  end
end
