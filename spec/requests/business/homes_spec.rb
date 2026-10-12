require 'rails_helper'

RSpec.describe "Business::Homes", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }

  def account_menu(html)
    html.at_css(".business-account-menu")
  end

  describe "GET /business のユーザーメニュー" do
    context "未ログイン" do
      it "汎用ユーザーアイコンのメニュー内にログイン導線を出し、ログアウト・ベルは出さない" do
        get business_root_path

        html = Nokogiri::HTML(response.body)
        menu = account_menu(html)
        toggle = menu.at_css("button.business-account-menu__toggle")

        expect(response).to have_http_status(:ok)
        expect(toggle["data-toggle"]).to eq "dropdown"
        expect(toggle["aria-haspopup"]).to eq "true"
        expect(toggle["aria-expanded"]).to eq "false"
        expect(toggle.at_css("i.fa-circle-user")).to be_present
        expect(menu.at_css(%(.dropdown-menu a[href="#{new_business_customer_session_path}"])).text).to eq "ログイン"
        expect(response.body).not_to include("ログアウト")
        expect(html.at_css(".business-header-bell")).to be_nil
        expect(html.at_css("button#open.header-menu-toggle")).to be_present
      end
    end

    context "ログイン済み" do
      let(:customer) { create(:customer, domain_name: "business", onboarding_done: true) }

      before { sign_in customer }

      it "メニュー内にプロフィール・設定・DELETE のログアウトを出し、ログインは出さない" do
        get business_root_path

        html = Nokogiri::HTML(response.body)
        menu = account_menu(html)
        logout_forms = html.css(%(form[action="#{destroy_customer_session_path}"]))

        # PC のドロップダウンと SP の☰メニューに1つずつ(表示は画面幅で切り替え)。
        expect(logout_forms.size).to eq 2
        expect(menu.at_css("form.business-account-menu__logout-form")).to eq logout_forms.first
        logout_forms.each { |form| expect(form.at_css('input[name="_method"]')["value"]).to eq "delete" }
        expect(logout_forms.first.at_css("button.dropdown-item").text.strip).to eq "ログアウト"
        expect(menu.at_css(%(a[href="#{business_customer_path(customer)}"])).text).to eq "プロフィール"
        expect(menu.at_css(%(a[href="#{edit_business_customer_path(customer)}"])).text).to eq "プロフィール設定"
        expect(response.body).not_to include(%(href="#{new_business_customer_session_path}"))
        expect(response.body).not_to include(%(href="#{new_customer_session_path}"))
      end

      it "プロフィール画像が未設定なら汎用アイコンを出す" do
        get business_root_path

        expect(account_menu(Nokogiri::HTML(response.body)).at_css(".business-account-menu__toggle i.fa-circle-user")).to be_present
      end

      context "プロフィール画像を設定済み" do
        let(:customer) do
          create(:customer, domain_name: "business", onboarding_done: true).tap do |record|
            record.profile_image.attach(
              io: File.open(Rails.root.join("app/assets/images/no_image.jpg")),
              filename: "me.jpg",
              content_type: "image/jpeg"
            )
          end
        end

        it "その画像をアイコンに出す" do
          get business_root_path

          toggle = account_menu(Nokogiri::HTML(response.body)).at_css(".business-account-menu__toggle")
          expect(toggle.at_css("img.business-account-menu__avatar")).to be_present
          expect(toggle.at_css("i.fa-circle-user")).to be_nil
        end
      end

      it "共通メニューのプロジェクトには、プラン契約が必須と読める案内を出さない" do
        get business_root_path

        html = Nokogiri::HTML(response.body)
        project_links = html.css(%(a[href="#{business_projects_path}"]))

        expect(project_links.size).to eq 2
        project_links.each do |link|
          expect(link.text.strip).to eq "プロジェクト"
          expect(link["class"]).not_to include("locked")
        end
      end

      it "ログアウトすると Business 専用ログインへ戻り、未ログイン状態になる" do
        delete destroy_customer_session_path, headers: { "HTTP_REFERER" => business_root_url }

        expect(response).to redirect_to(new_business_customer_session_path)

        get business_timeline_path
        expect(response).to redirect_to(new_customer_session_path)
      end
    end
  end
  describe "GET /business のトップ(料金表は置かない)" do
    def expect_no_pricing(body)
      expect(body).not_to include("business-pricing")
      expect(body).not_to include("料金プラン")
      expect(body).not_to include("プランUPGRADE")
      expect(body).not_to include("料金を見る")
      %w[light core premium].each { |plan| expect(body).not_to include(business_checkout_path(plan)) }
      expect(body).not_to include(business_portal_path)
    end

    it "未ログインでは料金表・購入誘導を出さない" do
      get business_root_path

      expect_no_pricing(response.body)
    end

    it "ログイン済み(free / light 契約者)でも料金表・購入誘導を出さない" do
      customer = create(:customer, domain_name: "business", onboarding_done: true)
      sign_in customer
      get business_root_path
      expect_no_pricing(response.body)

      create(:subscription, customer: customer, plan: "light")
      get business_root_path
      expect_no_pricing(response.body)
      expect(response.body).not_to include("契約中")
    end
  end

  describe "GET /business のプロジェクト一覧" do
    let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
    let(:community) { create(:community, owner: owner, domain: business_domain, name: "企画コミュニティ") }

    def project!(title, updated_at:, **attrs)
      Project.create!({ community: community, customer: owner, title: title, description: "#{title}の概要です" }.merge(attrs)).tap do |project|
        project.update_columns(updated_at: updated_at)
      end
    end

    def cards
      Nokogiri::HTML(response.body).css(".top-project-card")
    end

    def section
      Nokogiri::HTML(response.body).at_css("#top-projects")
    end

    context "未ログイン" do
      it "プロジェクトを取得・表示せず、名前や件数を出さずにログイン導線を出す" do
        project!("非公開になり得る企画", updated_at: 1.hour.ago)

        get business_root_path

        expect(response).to have_http_status(:ok)
        expect(cards).to be_empty
        expect(response.body).not_to include("非公開になり得る企画")
        expect(response.body).not_to include("企画コミュニティ")
        expect(section.text).to include("プロジェクトはログインすると閲覧できます。")
        expect(section.at_css(%(a[href="#{new_business_customer_session_path}"]))).to be_present
        expect(section.at_css(%(a[href="#{new_business_customer_registration_path}"]))).to be_present
        expect(section.at_css(%(a[href="#{business_projects_path}"]))).to be_nil
      end
    end

    context "ログイン済み" do
      let(:viewer) { create(:customer, domain_name: "business", onboarding_done: true) }

      before { sign_in viewer }

      it "0件ならコミュニティへの導線を出し、すべて見るは出さない" do
        get business_root_path

        expect(cards).to be_empty
        expect(section.text).to include("まだプロジェクトはありません。")
        expect(section.at_css(%(a[href="#{business_communities_path}"]))).to be_present
        expect(section.at_css(%(a[href="#{business_projects_path}"]))).to be_nil
      end

      it "更新が新しい順に6件まで、名前・コミュニティ・概要・詳細リンクを表示し、一覧への導線を出す" do
        projects = (1..8).map { |i| project!("企画#{i}", updated_at: i.hours.ago) }

        get business_root_path

        expect(cards.size).to eq 6
        expect(cards.map { |card| card.at_css(".top-project-card__title").text }).to eq projects.first(6).map(&:title)
        first = cards.first
        expect(first.at_css(".top-project-card__community").text).to eq "企画コミュニティ"
        expect(first.at_css(".top-project-card__description").text).to eq "企画1の概要です"
        expect(first.at_css(%(a[href="#{business_project_path(projects.first)}"]))).to be_present
        expect(response.body).not_to include("企画7")
        expect(section.css(%(a[href="#{business_projects_path}"])).size).to eq 2
      end

      it "参加状況(主催 / 参加中 / 募集終了 / 参加できます / コミュニティ参加が必要)を出す" do
        other_community = create(:community, owner: owner, domain: business_domain)
        CommunityCustomer.create!(community: community, customer: viewer)
        hosted = project!("主催企画", updated_at: 1.minute.ago, customer: viewer)
        joined = project!("参加企画", updated_at: 2.minutes.ago).tap { |p| p.members << viewer }
        closed = project!("終了企画", updated_at: 3.minutes.ago, deadline: 1.day.ago)
        open = project!("募集企画", updated_at: 4.minutes.ago)
        outside = project!("外の企画", updated_at: 5.minutes.ago, community: other_community)

        get business_root_path

        status = cards.to_h { |card| [card.at_css(".top-project-card__title").text, card.at_css(".top-project-card__status").text] }
        expect(status).to eq(
          hosted.title => "主催",
          joined.title => "参加中",
          closed.title => "募集終了",
          open.title => "参加できます",
          outside.title => "コミュニティ参加後に参加できます"
        )
      end

      it "画像があれば表示し、Business 以外のコミュニティのプロジェクトは出さない" do
        with_image = project!("画像あり企画", updated_at: 1.minute.ago)
        with_image.project_image.attach(io: File.open(Rails.root.join("app/assets/images/no_image.jpg")), filename: "p.jpg", content_type: "image/jpeg")
        project!("音楽側の企画", updated_at: Time.current, community: create(:community, owner: owner))

        get business_root_path

        expect(cards.first.at_css(".top-project-card__image img")).to be_present
        expect(response.body).not_to include("音楽側の企画")
      end
    end
  end

  describe "ヘッダー(SP の☰メニュー)" do
    def sp_menu
      Nokogiri::HTML(response.body).at_css("#businessSpMenu")
    end

    it "未ログイン: ☰にログイン・新規登録をまとめ、アイコンはログイン画面へのリンク" do
      get business_root_path

      html = Nokogiri::HTML(response.body)
      expect(html.at_css("button#open")["aria-controls"]).to eq "businessSpMenu"
      expect(html.at_css("button#open")["aria-expanded"]).to eq "false"
      expect(html.at_css(%(a.business-account-link[href="#{new_business_customer_session_path}"]))).to be_present
      expect(sp_menu.css("a").map { |a| a.text.strip }).to eq %w[HOME ログイン 新規登録]
    end

    it "ログイン済み: ☰に移動項目とアカウント項目を重複なくまとめ、アイコンはプロフィールへのリンク" do
      customer = create(:customer, domain_name: "business", onboarding_done: true)
      sign_in customer

      get business_root_path

      html = Nokogiri::HTML(response.body)
      expect(html.at_css(%(a.business-account-link[href="#{business_customer_path(customer)}"]))).to be_present
      labels = sp_menu.css("a, button").map { |el| el.text.strip.split.first }
      expect(labels).to eq %w[閉じる HOME タイムライン コミュニティ 投稿 プロジェクト プロフィール プロフィール設定 通知 ログアウト]
      expect(labels.uniq).to eq labels
      logout = sp_menu.at_css(%(form[action="#{destroy_customer_session_path}"]))
      expect(logout.at_css('input[name="_method"]')["value"]).to eq "delete"
    end
  end
end
