require "rails_helper"

# 集金チェック票(スマホ)。受付で片手のまま押せるよう、各行の切り替えボタンが十分な大きさで
# 画面内の右端に収まり、押すと集金済み⇔未集金が切り替わって人数表示も変わること。
#
# 他の system spec と同じ理由(このheadless Chrome環境では実クリックがDOMへ反映されないことがある)で、
# クリックは page.execute_script で行う。
RSpec.describe "集金チェック票(スマホ)", type: :system do
  before { driven_by :selenium_chrome_headless }
  after { reset_viewport_override }

  let(:community) { create(:community) }
  let(:owner) { create(:customer, name: "主催オーナー") }
  let(:vocal) { create(:customer, name: "とても長い名前のボーカル担当メンバーさん") }
  let(:guitar) { create(:customer, name: "ギター会員") }
  let(:event) { create(:event, :event_with_songs, community: community, customer: owner) }

  before do
    community.update!(owner_id: owner.id)
    [owner, vocal, guitar].each { |c| CommunityCustomer.find_or_create_by!(customer: c, community: community) }
    song = event.songs.first
    create(:join_part_customer, join_part: create(:join_part, song: song, join_part_name: "Vocal"), customer: vocal)
    create(:join_part_customer, join_part: create(:join_part, song: song, join_part_name: "Guitar"), customer: guitar)
  end

  def sign_in_via_form(target)
    visit new_customer_session_path
    fill_in "customer_email", with: target.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def toggle_metrics(customer)
    page.evaluate_script(<<~JS)
      (function () {
        var button = document.querySelector('#payment-check-#{customer.id} .payment-checklist__toggle');
        var rect = button.getBoundingClientRect();
        return { height: rect.height, width: rect.width, right: rect.right, viewport: document.documentElement.clientWidth };
      })()
    JS
  end

  # 合計欄の各金額と、各行の参加費が切れたり画面からはみ出したりしていないこと。
  def amount_overflows
    page.evaluate_script(<<~JS)
      (function () {
        var width = document.documentElement.clientWidth;
        var els = document.querySelectorAll('.payment-checklist__total dd, .payment-checklist__fee');
        return Array.prototype.filter.call(els, function (el) {
          var rect = el.getBoundingClientRect();
          return rect.right > width || rect.left < 0 || el.scrollWidth > el.clientWidth + 1;
        }).map(function (el) { return el.textContent.trim(); });
      })()
    JS
  end

  def totals_text
    all(".payment-checklist__total dd").map(&:text)
  end

  it "375px幅でボタンが大きく画面内に収まり、集金済みの保存と取消ができる" do
    sign_in_via_form(owner)
    use_mobile_viewport(width: 375, height: 812)
    visit public_event_payment_checks_path(event)

    expect(page).to have_css(".payment-checklist__row", count: 2)
    expect(totals_text).to eq ["3,000円", "0円", "3,000円"]
    expect(amount_overflows).to eq []
    expect(page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.payment-checklist__total dd')).fontSize)")).to be >= 16
    metrics = toggle_metrics(vocal)
    expect(metrics["height"]).to be >= 44
    expect(metrics["width"]).to be >= 44
    expect(metrics["right"]).to be <= metrics["viewport"]
    expect(metrics["right"]).to be > metrics["viewport"] / 2

    page.execute_script("document.querySelector('#payment-check-#{vocal.id} .payment-checklist__toggle').click()")
    expect(page).to have_css("#payment-check-#{vocal.id}.payment-checklist__row--collected", wait: 10)
    expect(find(".payment-checklist__summary").text.gsub(/\s+/, "")).to eq "集金済み1/2人"
    expect(totals_text).to eq ["3,000円", "1,500円", "1,500円"]

    page.execute_script("document.querySelector('#payment-check-#{vocal.id} .payment-checklist__toggle').click()")
    expect(page).to have_no_css("#payment-check-#{vocal.id}.payment-checklist__row--collected", wait: 10)
    expect(find(".payment-checklist__summary").text.gsub(/\s+/, "")).to eq "集金済み0/2人"
    expect(totals_text).to eq ["3,000円", "0円", "3,000円"]
    expect(EventPaymentCheck.find_by!(event: event, customer: vocal).collected).to be false
  end
end
