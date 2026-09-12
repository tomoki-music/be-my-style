require "rails_helper"

# イベント楽曲一覧(.responsive-box / .event-songs-table)のPC横幅追従。
#
# 修正前の原因: .responsive-boxが@media(min-width:768px)で固定800pxだったため、
# ブラウザの表示倍率を下げる/画面を広げるほど.col-md-9側に余白が残っていた。
# 修正後は.responsive-boxをPC(768px以上)でwidth:100%(親要素いっぱい)にし、
# .event-songs-table側もwidth:100%にしてtable-layout:fixedの各列(%指定)が
# 比例して広がるようにした(単一のPC幅決め打ちにしないため、複数の幅で検証する)。
#
# スマホ(768px未満)は従来どおり.responsive-box width:280pxのまま(横スクロール前提)で
# 変更していないことも合わせて確認する。
RSpec.describe "イベント楽曲一覧のPC横幅追従", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer) }
  let(:community) { create(:community, owner_id: customer.id) }
  let(:event) do
    create(
      :event, :event_with_songs, customer: customer, community: community,
      event_start_time: 3.days.from_now, event_end_time: 3.days.from_now + 2.hours
    )
  end

  before do
    CommunityOwner.find_or_create_by!(customer: customer, community: community)
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def responsive_box_width
    page.evaluate_script("document.querySelector('.responsive-box').getBoundingClientRect().width")
  end

  # .responsive-boxの直接の親(.responsive-wrapper、padding無し)の実クライアント幅。
  # 「親要素の利用可能な横幅いっぱいに広がっているか」の比較対象にする
  # (祖先の.event-songs-join-formはpadding:15pxを持つため、そちらと比較すると
  # そのpadding分だけ意図的に短くなり誤検知するため使わない)。
  def parent_available_width
    page.evaluate_script("document.querySelector('.responsive-wrapper').clientWidth")
  end

  [1280, 1600].each do |width|
    it "PC幅#{width}pxで.responsive-boxが固定800pxに戻らず、親要素の幅まで広がること" do
      sign_in_via_form(customer)
      use_desktop_viewport(width: width, height: 900)
      visit public_event_path(event)

      expect(page).to have_selector(".responsive-box", wait: 10)
      expect(responsive_box_width).to be > 800
      expect(responsive_box_width).to be_within(2).of(parent_available_width)
    end
  end

  it "PC幅でも既存の「すべて表示」「楽曲成立」「募集中」の絞り込みが維持されること" do
    vacant_song = event.songs.first
    vacant_song.update!(song_name: "募集中の曲")
    create(:join_part, song: vacant_song, join_part_name: "ボーカル")

    complete_song = create(:song, event: event, song_name: "成立済みの曲")

    sign_in_via_form(customer)
    use_desktop_viewport(width: 1280, height: 900)
    visit public_event_path(event)

    expect(page).to have_content("募集中の曲", wait: 10)
    expect(page).to have_content("成立済みの曲")

    click_on "楽曲成立"
    expect(page).to have_content("成立済みの曲")
    expect(page).to have_no_content("募集中の曲")

    click_on "募集中"
    expect(page).to have_content("募集中の曲")
    expect(page).to have_no_content("成立済みの曲")

    click_on "すべて表示"
    expect(page).to have_content("募集中の曲")
    expect(page).to have_content("成立済みの曲")
  end

  context "モバイル幅(375x812)" do
    it ".responsive-boxが横スクロール前提の狭い幅のまま維持されること(PC対応で崩れていないこと)" do
      sign_in_via_form(customer)
      # CDP override はページ描画済みの状態でしか効かないため sign_in 後・本画面 visit 前に適用する
      use_mobile_viewport(width: 375, height: 812)
      visit public_event_path(event)

      expect(page).to have_selector(".responsive-box", wait: 10)
      expect(responsive_box_width).to be <= 300

      scrollable = page.evaluate_script(
        "(function(){var b=document.querySelector('.responsive-box');return b.scrollWidth > b.clientWidth;})()"
      )
      expect(scrollable).to eq true
    end
  end
end
