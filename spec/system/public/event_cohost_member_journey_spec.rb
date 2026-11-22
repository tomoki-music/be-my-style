require "rails_helper"

RSpec.describe "共催先だけに所属するメンバーのイベント参加導線", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:organizer) { create(:customer) }
  let!(:western) { create(:community, name: "洋楽セッション", owner_id: organizer.id) }
  let!(:japanese) { create(:community, name: "邦楽セッション", owner_id: organizer.id) }
  let!(:jazz) { create(:community, name: "ジャズセッション", owner_id: organizer.id) }
  let!(:event) do
    create(:event, :event_with_songs,
      customer: organizer, community: western, event_name: "合同セッション",
      event_start_time: 30.days.from_now, event_end_time: 30.days.from_now + 2.hours, event_entry_deadline: 20.days.from_now)
  end
  let!(:vocal) { create(:join_part, song: event.songs.first, join_part_name: "Vocal") }
  let(:japanese_member) { create(:customer).tap { |customer| CommunityCustomer.create!(customer: customer, community: japanese) } }
  let(:outsider) { create(:customer).tap { |customer| CommunityCustomer.create!(customer: customer, community: jazz) } }

  before { event.update!(selected_cohost_community_ids: [japanese.id]) }
  after { reset_viewport_override }

  def sign_in_via_form(customer)
    visit new_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
    use_desktop_viewport
  end

  def open_event_from_list
    within(".event-index-container") { find("a[href='#{public_event_path(event)}']", match: :first).click }
    expect(page).to have_current_path(public_event_path(event), wait: 10)
  end

  def go_to_join_confirmation
    check "event_join_part_ids_#{vocal.id}", allow_label_click: true
    accept_confirm { click_button "参加確認画面へ" }
    expect(page).to have_content("参加確認画面", wait: 10)
  end

  def event_cards
    all(".event-index-container .card.mb-5")
  end

  it "ホームのコミュニティカードから一覧へ進み、詳細を開いて参加を確定できる" do
    sign_in_via_form(japanese_member)

    visit root_path
    click_link "イベントを見る", match: :first
    expect(page).to have_current_path(/community_id=#{japanese.id}/, url: true, wait: 10)
    expect(event_cards.size).to eq 1
    expect(page).to have_content("洋楽セッション / 邦楽セッション")

    open_event_from_list
    expect(page).to have_content("【洋楽セッション】【邦楽セッション】のいずれかに参加している必要があります。")
    go_to_join_confirmation

    accept_confirm { click_button "参加する" }
    expect(page).to have_content("イベントへの参加が完了しました", wait: 10)
    expect(JoinPartCustomer.where(customer: japanese_member, join_part: vocal).count).to eq 1
  end

  it "イベント一覧のキーワード検索で共催先の名前からも見つけて詳細を開ける" do
    sign_in_via_form(japanese_member)

    visit public_events_path
    fill_in "keyword", with: "邦楽"
    click_button "検索する"

    expect(page).to have_current_path(/keyword=/, url: true, wait: 10)
    expect(event_cards.size).to eq 1
    open_event_from_list
    expect(page).to have_content("合同セッション")
  end

  it "共催先コミュニティのページの開催予定から詳細を開ける" do
    sign_in_via_form(japanese_member)

    visit public_community_path(japanese)
    find(".community-upcoming-events a[href='#{public_event_path(event)}']", match: :first).click

    expect(page).to have_current_path(public_event_path(event), wait: 10)
  end

  it "どの開催コミュニティにも所属しない人は詳細まで見られるが、確定すると参加できず案内される" do
    sign_in_via_form(outsider)

    visit public_event_path(event)
    go_to_join_confirmation

    accept_confirm { click_button "参加する" }
    expect(page).to have_current_path(public_community_path(western), wait: 10)
    expect(page).to have_content("まずこちらのコミュニティに参加してください")
    expect(JoinPartCustomer.where(customer: outsider).count).to eq 0
  end
end
