require 'rails_helper'

RSpec.describe "Business::Homes", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }

  def account_menu(html)
    html.at_css(".business-account-menu")
  end

  describe "GET /business のユーザーメニュー" do
    context "未ログイン" do
      it "ログイン済みに見えるアカウントアイコン・通知ベル・ログアウトを出さず、ヘッダーにログインと新規登録を出す" do
        get business_root_path

        html = Nokogiri::HTML(response.body)
        header = html.at_css("header.ba-lp-header")

        expect(response).to have_http_status(:ok)
        expect(header.at_css(%(a[href="#{new_business_customer_session_path}"])).text.strip).to eq "ログイン"
        expect(header.at_css(%(a[href="#{new_business_customer_registration_path}"])).text.strip).to eq "無料で始める"
        expect(html.at_css(".business-account-menu, .business-account-link, .business-header-bell, i.fa-circle-user")).to be_nil
        expect(response.body).not_to include("ログアウト")
        expect(html.at_css(".header_container--business")).to be_nil
      end
    end

    context "ログイン済み" do
      let(:customer) { create(:customer, domain_name: "business", onboarding_done: true) }

      before { sign_in customer }

      it "左ナビと SP のメニューにプロフィール・設定・DELETE のログアウトを出し、ログインは出さない" do
        get business_root_path

        html = Nokogiri::HTML(response.body)
        logout_forms = html.css(%(form[action="#{destroy_customer_session_path}"]))

        # PC の左ナビと SP のメニューシートに1つずつ(表示は画面幅で切り替え)。
        expect(logout_forms.size).to eq 2
        expect(logout_forms.map { |form| form["class"] }).to contain_exactly("ba-sidenav__logout-form", "ba-sheet__logout-form")
        logout_forms.each do |form|
          expect(form.at_css('input[name="_method"]')["value"]).to eq "delete"
          expect(form.at_css("button").text.strip).to eq "ログアウト"
        end
        [".ba-sidenav__account", "#baMenuSheet"].each do |scope|
          expect(html.at_css(%(#{scope} a[href="#{business_customer_path(customer)}"]))).to be_present
        end
        # 左ナビは縮約時に短い表示(「設定」)にするため、読み上げ名で確かめる。
        expect(html.at_css(%(.ba-sidenav__account a[href="#{edit_business_customer_path(customer)}"]))["aria-label"]).to eq "プロフィール設定"
        expect(html.at_css(%(#baMenuSheet a[href="#{edit_business_customer_path(customer)}"])).text.strip).to eq "プロフィール設定"
        expect(response.body).not_to include(%(href="#{new_business_customer_session_path}"))
        expect(response.body).not_to include(%(href="#{new_customer_session_path}"))
      end

      it "プロフィール画像が未設定なら汎用アイコンを出す" do
        get business_root_path

        expect(Nokogiri::HTML(response.body).at_css(".ba-sidenav__profile i.fa-circle-user")).to be_present
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

          profile = Nokogiri::HTML(response.body).at_css(".ba-sidenav__profile")
          expect(profile.at_css("img.business-account-menu__avatar")).to be_present
          expect(profile.at_css("i.fa-circle-user")).to be_nil
        end
      end

      it "共通メニューのプロジェクトには、プラン契約が必須と読める案内を出さない" do
        get business_root_path

        html = Nokogiri::HTML(response.body)
        # 本文(ログイン後ホーム)の「プロジェクトを探す」は除き、共通メニュー(PC の左ナビ・SP の下部ナビ)だけを見る。
        project_links = html.css(%(a[href="#{business_projects_path}"])).reject { |link| link.ancestors(".ba-main").any? }

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
        expect(response).to redirect_to(new_business_customer_session_path)
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

  describe "GET /business の本文" do
    let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
    let(:community) { create(:community, owner: owner, domain: business_domain, name: "企画コミュニティ") }

    def doc
      Nokogiri::HTML(response.body)
    end

    context "未ログイン" do
      it "紹介ページを出し、実際のコミュニティ・プロジェクトを取得・表示せず登録・ログインへ案内する" do
        Project.create!(community: community, customer: owner, title: "非公開になり得る企画")

        get business_root_path

        expect(response).to have_http_status(:ok)
        expect(doc.at_css("body.ba-lp")).to be_present
        expect(doc.at_css("body.ba-body, .ba-home, .ba-sidenav, .ba-bottomnav")).to be_nil
        expect(doc.at_css("h1").text).to eq "出会いを、いっしょに動く力へ。"
        expect(response.body).not_to include("非公開になり得る企画")
        expect(response.body).not_to include("企画コミュニティ")
        start = doc.at_css("#ba-lp-start")
        expect(start.text).to include("コミュニティ内の会話やプロジェクトのスレッドは、参加したメンバーが見られます")
        expect(start.at_css(%(a[href="#{new_business_customer_session_path}"]))).to be_present
        expect(start.at_css(%(a[href="#{new_business_customer_registration_path}"]))).to be_present
      end

      it "画面イメージは架空の例と明記し、読み上げでは中身を実データとして読ませない" do
        get business_root_path

        preview = doc.at_css("figure.ba-lp-preview")
        expect(preview.at_css("figcaption").text).to include("画面イメージ（架空の例）")
        expect(preview.at_css(".ba-lp-preview__body")["aria-hidden"]).to eq "true"
        expect(preview.css(".ba-nav-badge, .ba-count")).to be_empty
      end

      it "無料の範囲を誤解させない注記を添え、音楽側への案内を出さない" do
        get business_root_path

        expect(doc.at_css(".ba-lp-note").text).to include("無料で登録・参加できます", "作成には、有料プランなどの条件があります")
        hrefs = doc.css("a").map { |a| a["href"].to_s }
        expect(hrefs).not_to include("/")
        expect(hrefs.grep(%r{\A/(singing|public/(communities|events|lp))})).to eq []
        expect(response.body).not_to include("音楽")
      end

      it "フッターの法務ページ・ログイン・新規登録のリンクが実在するページを指す" do
        get business_root_path

        links = doc.css(".ba-lp-footer a[href^='/']").map { |a| a["href"] }.uniq
        expect(links).to include(public_terms_path, public_privacy_path, public_legal_path,
                                 new_business_customer_session_path, new_business_customer_registration_path)
        links.each do |href|
          get href
          expect(response).to have_http_status(:ok), href
        end
      end
    end

    context "ログイン済み" do
      let(:viewer) { create(:customer, domain_name: "business", onboarding_done: true) }

      before { sign_in viewer }

      it "紹介用のヒーロー・スライダー・お知らせを出さず、コミュニティ・プロジェクトの2つの一覧にする" do
        get business_root_path

        expect(doc.at_css(".hero-section, .business-top-slider, .notice-section, #top-projects")).to be_nil
        expect(doc.css(".ba-home__section").map { |s| s["id"] }).to eq %w[my-communities my-projects]
        # ログイン後は Business の枠(左ナビ・下部ナビ)で表示し、ログイン前の紹介用ヘッダーは出さない。
        expect(doc.at_css("body.ba-body nav.ba-sidenav")).to be_present
        expect(doc.at_css(".header_container--business")).to be_nil
      end

      it "0件ならBusinessコミュニティ・プロジェクトを探す導線を出す" do
        get business_root_path

        expect(doc.at_css("#my-communities").text).to include("参加しているコミュニティはまだありません。")
        expect(doc.at_css(%(#my-communities a[href="#{business_communities_path}"]))).to be_present
        expect(doc.at_css(%(#my-communities a[href="#{public_communities_path}"]))).to be_nil
        expect(doc.at_css(%(#my-projects a[href="#{business_projects_path}"]))).to be_present
        expect(doc.at_css(%(#my-projects a[href="#{business_communities_path}"]))).to be_present
      end

      it "参加中・主催・承認待ちのプロジェクトだけを出し、参加していないものは出さない" do
        CommunityCustomer.create!(community: community, customer: viewer)
        Project.create!(community: community, customer: viewer, title: "主催企画")
        Project.create!(community: community, customer: owner, title: "参加企画").tap { |p| p.members << viewer }
        Project.create!(community: community, customer: owner, title: "申請中企画").tap { |p| ProjectJoinRequest.create!(project: p, customer: viewer) }
        Project.create!(community: community, customer: owner, title: "未参加企画")

        get business_root_path

        status = doc.css("#my-projects .ba-project-card").to_h do |card|
          [card.at_css(".ba-project-card__title").text, card.at_css(".ba-status").text.strip]
        end
        expect(status).to eq("主催企画" => "主催", "参加企画" => "参加中", "申請中企画" => "承認待ち")
        expect(response.body).not_to include("未参加企画")
      end

      it "承認待ちのプロジェクトのリンク先では概要だけが見え、スレッドは見えない(表示と認可が一致する)" do
        CommunityCustomer.create!(community: community, customer: viewer)
        project = Project.create!(community: community, customer: owner, title: "申請中企画")
        ProjectJoinRequest.create!(project: project, customer: viewer)

        get business_root_path
        expect(doc.at_css(%(#my-projects a[href="#{business_project_path(project)}"]))).to be_present

        get business_project_path(project)
        expect(response).to have_http_status(:ok)
        get business_project_thread_path(project, ProjectThread.default_for(project))
        expect(response).to have_http_status(:redirect)
      end

      it "コミュニティのアクセス停止後は、そのコミュニティとプロジェクトを一覧に出さない" do
        CommunityCustomer.create!(community: community, customer: viewer)
        Project.create!(community: community, customer: owner, title: "参加企画").tap { |p| p.members << viewer }
        Business::Memberships::RevokeCommunityAccess.call(community: community, customer: viewer, suspend: true, actor: owner)

        get business_root_path

        expect(response.body).not_to include("企画コミュニティ")
        expect(response.body).not_to include("参加企画")
      end

      it "コミュニティ運営者には運営・管理として出す" do
        sign_in owner
        CommunityCustomer.create!(community: community, customer: owner)
        Project.create!(community: community, customer: create(:customer, domain_name: "business"), title: "メンバーの企画")

        get business_root_path

        expect(doc.at_css("#my-communities .ba-status").text.strip).to eq "運営"
        expect(doc.at_css("#my-projects .ba-status").text.strip).to eq "管理"
      end
    end
  end

  describe "ヘッダー(ログイン後の下部ナビ・メニュー)" do
    it "ログイン済み: 下部ナビとメニューに移動項目・アカウント項目を重複なくまとめる" do
      customer = create(:customer, domain_name: "business", onboarding_done: true)
      sign_in customer

      get business_root_path

      html = Nokogiri::HTML(response.body)
      expect(html.at_css("#businessSpMenu")).to be_nil
      bottom = html.css(".ba-bottomnav a, .ba-bottomnav button").map { |el| el.text.strip.split.first }
      expect(bottom).to eq %w[ホーム コミュニティ プロジェクト 通知 メニュー]
      toggle = html.at_css("button#baMenuToggle")
      expect(toggle["aria-controls"]).to eq "baMenuSheet"
      expect(toggle["aria-expanded"]).to eq "false"

      sheet = html.at_css("#baMenuSheet")
      expect(sheet.at_css(%(a.ba-sheet__profile[href="#{business_customer_path(customer)}"]))).to be_present
      labels = sheet.css(".ba-sheet__list a, .ba-sheet__list button").map { |el| el.text.strip.split.first }
      expect(labels).to eq %w[タイムライン 使い方 プロフィール設定 ログアウト]
      expect((bottom + labels).uniq).to eq bottom + labels
      logout = sheet.at_css(%(form[action="#{destroy_customer_session_path}"]))
      expect(logout.at_css('input[name="_method"]')["value"]).to eq "delete"
    end
  end
end
