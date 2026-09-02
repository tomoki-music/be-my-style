require "rails_helper"

# PC ヘッダーの情報設計（主要メニュー + プロフィールドロップダウン）と、
# SP メニュー（.customer-menu-sp）を従来どおり維持していることの回帰テスト。
RSpec.describe "layouts/_header_menu", type: :view do
  let(:customer) { create(:customer) }

  def stub_common_helpers(signed_in:, current: nil, chat_available: true)
    without_partial_double_verification do
      allow(view).to receive(:customer_signed_in?).and_return(signed_in)
      allow(view).to receive(:current_customer).and_return(current)
      allow(view).to receive(:unchecked_notifications).and_return([])
      allow(view).to receive(:customer_avatar_tag).and_return("avatar".html_safe)
      allow(view).to receive(:feature_available?).and_return(true)
      allow(view).to receive(:feature_available?).with(:music_direct_chat).and_return(chat_available)
      allow(view).to receive(:feature_locked_badge).with(:music_direct_chat).and_return("要プラン".html_safe)
    end
  end

  def pc_menu
    Nokogiri::HTML(rendered).at_css(".customer-menu-pc")
  end

  def pc_main
    Nokogiri::HTML(rendered).at_css(".customer-menu-pc .customer-menu-pc__main")
  end

  def profile_menu
    Nokogiri::HTML(rendered).at_css(".customer-menu-pc .customer-profile-menu")
  end

  def pc_account
    Nokogiri::HTML(rendered).at_css(".customer-menu-pc .customer-menu-pc__account")
  end

  def sp_menu
    Nokogiri::HTML(rendered).at_css(".customer-menu-sp")
  end

  describe "ログイン時" do
    before do
      stub_common_helpers(signed_in: true, current: customer)
      render partial: "layouts/header_menu"
    end

    it "PC メインメニューは主要 6 項目（短縮ラベル）だけを表示する" do
      labels = pc_main.css("li a").map { |a| a.text.gsub(/\s+/, "") }
      expect(labels).to eq(%w[コミュニティ イベント チャット 活動報告 ランキング 歌唱・演奏診断])
    end

    it "PC メインメニューに Topページ / マイページ / BeMyStyleとは？ / ご意見BOX / プランUPGRADE を表示しない" do
      text = pc_main.text
      expect(text).not_to include("Topページ")
      expect(text).not_to include("マイページ")
      expect(text).not_to include("BeMyStyleとは？")
      expect(text).not_to include("ご意見BOX")
      expect(text).not_to include("プランUPGRADE")
    end

    it "PC メインメニュー各項目のリンク先が既存ルートと一致する" do
      hrefs = pc_main.css("li a").map { |a| a["href"] }
      expect(hrefs).to eq([
        public_communities_path,
        public_events_path,
        public_matchings_path,
        public_activities_path,
        public_song_rankings_path,
        public_singing_performance_diagnosis_path,
      ])
    end

    it "プロフィールドロップダウンに 6 項目（マイページ / ユーザー演奏実績ランキング / プランUPGRADE / BeMyStyleとは？ / ご意見BOX / ログアウト）がある" do
      menu = profile_menu.at_css(".dropdown-menu")
      link_labels = menu.css("a.dropdown-item").map { |a| a.text.gsub(/\s+/, "") }
      expect(link_labels).to eq(%w[マイページ ユーザー演奏実績ランキング プランUPGRADE BeMyStyleとは？ ご意見BOX])

      logout = menu.at_css("form.customer-profile-menu__logout-form button")
      expect(logout.text.strip).to eq("ログアウト")
    end

    it "プロフィールドロップダウンのリンク先が既存ルートと一致する" do
      menu = profile_menu.at_css(".dropdown-menu")
      hrefs = menu.css("a.dropdown-item").map { |a| a["href"] }
      expect(hrefs).to eq([
        public_customer_path(customer),
        public_performance_rankings_path,
        public_lp_path(anchor: "lp-section"),
        public_homes_about_path,
        new_public_customer_feedback_path,
      ])
    end

    it "ログアウトは DELETE の button_to（CSRF トークン付き）で維持される" do
      form = profile_menu.at_css(".dropdown-menu form.customer-profile-menu__logout-form")
      expect(form["action"]).to eq(destroy_customer_session_path)
      expect(form["method"]).to eq("post")
      expect(form.at_css('input[name="_method"]')["value"]).to eq("delete")
    end

    it "プロフィールトグルは button 要素で aria 属性を持つ（a href=# ではない）" do
      toggle = profile_menu.at_css(".customer-profile-menu__toggle")
      expect(toggle.name).to eq("button")
      expect(toggle["type"]).to eq("button")
      expect(toggle["data-toggle"]).to eq("dropdown")
      expect(toggle["aria-haspopup"]).to eq("true")
      expect(toggle["aria-expanded"]).to eq("false")
      expect(toggle["aria-label"]).to be_present
    end

    it "プランUPGRADE はドロップダウン内で控えめに強調される（専用クラス、派手な CTA クラスは使わない）" do
      upgrade = profile_menu.at_css(".dropdown-menu .customer-profile-menu__upgrade")
      expect(upgrade).to be_present
      expect(upgrade["class"]).to include("dropdown-item")
      expect(upgrade["class"]).not_to include("menu-upgrade-cta")
    end

    it "PC ヘッダー右端は 通知ベル + プロフィール を 1 つのユーティリティ領域(.customer-menu-pc__account)にまとめる" do
      account = pc_account
      expect(account).to be_present

      children = account.element_children
      # 通知ベル(左) → プロフィール dropdown(右) の順
      expect(children[0]["class"]).to include("customer-menu-pc__notification")
      expect(children[1]["class"]).to include("customer-profile-menu")
    end

    it "PC の通知ベルは公開通知一覧へのリンクで、dropdown の外に常時表示される" do
      bell = pc_account.at_css(".customer-menu-pc__notification a")
      expect(bell["href"]).to eq(public_notifications_path)
      expect(bell.at_css("i.fa-bell")).to be_present
      # dropdown-menu の内側に通知ベルを入れない
      expect(profile_menu.at_css(".dropdown-menu .fa-bell")).to be_nil
    end

    it "上部バー(.header-sign-in-list)の通知ベルは PC 用マークアップと二重に出さない（SP 用にクラスを付ける）" do
      top_bar = Nokogiri::HTML(rendered).at_css(".header-sign-in-list")
      bell_li = top_bar.at_css("li.header-sign-in-list__notification")
      expect(bell_li).to be_present
      expect(bell_li.at_css("a")["href"]).to eq(public_notifications_path)
      # 上部バーの通知ベルはこの 1 箇所だけ
      expect(top_bar.css("a[href='#{public_notifications_path}']").size).to eq(1)
    end

    it "SP メニューは従来の主要導線（正式名称ラベル）をすべて維持する" do
      text = sp_menu.text
      %w[
        Topページ BeMyStyleとは？ コミュニティ一覧 マイページ 個別チャット
        みんなの活動報告 イベント参加 成立楽曲ランキング 歌唱・演奏診断 ご意見BOX プランUPGRADE
      ].each do |label|
        expect(text).to include(label)
      end
      expect(sp_menu.at_css('form input[type="submit"]')["value"]).to eq("ログアウト")
    end

    it "ヘッダーロゴが Top ページへのリンクでアクセシブルネームを持つ" do
      logo = Nokogiri::HTML(rendered).at_css(".top-message a.top-message-link")
      expect(logo["href"]).to eq(public_homes_top_path)
      expect(logo["aria-label"]).to be_present
    end

    it "PC メニューに Topページ リンクを表示しない（ロゴへ統合）" do
      expect(pc_menu.css("a").map { |a| a["href"] }).not_to include(public_homes_top_path)
    end
  end

  describe "ログイン時（個別チャットがロック状態）" do
    before do
      stub_common_helpers(signed_in: true, current: customer, chat_available: false)
      render partial: "layouts/header_menu"
    end

    it "チャットボタンにロッククラスとロックバッジが付く" do
      chat_link = pc_main.css("li a").find { |a| a.text.include?("チャット") }
      expect(chat_link["class"]).to include("menu-sp-btn-locked")
      expect(chat_link["href"]).to eq(public_matchings_path)
      expect(chat_link.at_css(".menu-lock-note")).to be_present
    end
  end

  describe "未ログイン時" do
    before do
      stub_common_helpers(signed_in: false, current: nil)
      render partial: "layouts/header_menu"
    end

    it "PC メニューは BeMyStyleとは？ / ランキング / 料金を見る の 3 項目" do
      links = pc_main.css("li a")
      expect(links.size).to eq(3)
      expect(links[0].text.strip).to eq("BeMyStyleとは？")
      expect(links[1].text.strip).to eq("ランキング")
      expect(links[2].at_css(".menu-upgrade-cta__label").text.strip).to eq("料金を見る")
    end

    it "PC メニューに Topページ を表示しない" do
      expect(pc_main.text).not_to include("Topページ")
    end

    it "プロフィールドロップダウンを表示しない" do
      expect(profile_menu).to be_nil
    end

    it "未ログイン時は PC ユーティリティ領域も通知ベルも表示しない" do
      expect(pc_account).to be_nil
      expect(Nokogiri::HTML(rendered).at_css(".customer-menu-pc .customer-menu-pc__notification")).to be_nil
    end

    it "ランキングリンクは公開 URL（/song_rankings）を指す" do
      ranking = pc_main.css("li a").find { |a| a.text.strip == "ランキング" }
      expect(ranking["href"]).to eq(public_song_rankings_path)
    end

    it "SP メニューは新規登録 / ログイン / Topページ / BeMyStyleとは？ / 成立楽曲ランキング を維持する" do
      text = sp_menu.text
      %w[新規登録 ログイン Topページ BeMyStyleとは？ 成立楽曲ランキング].each do |label|
        expect(text).to include(label)
      end
    end
  end
end
