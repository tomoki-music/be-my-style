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
        # 本文(ログイン後ホーム)の「プロジェクトを探す」は除き、共通メニューだけを見る。
        project_links = html.css(%(a[href="#{business_projects_path}"])).reject { |link| link.ancestors(".member-home").any? }

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

  describe "GET /business の本文" do
    let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
    let(:community) { create(:community, owner: owner, domain: business_domain, name: "企画コミュニティ") }

    def doc
      Nokogiri::HTML(response.body)
    end

    context "未ログイン" do
      it "紹介ページのまま、プロジェクトを取得・表示せずログイン導線を出す" do
        Project.create!(community: community, customer: owner, title: "非公開になり得る企画")

        get business_root_path

        expect(response).to have_http_status(:ok)
        expect(doc.at_css(".hero-section")).to be_present
        expect(doc.at_css(".member-home")).to be_nil
        expect(response.body).not_to include("非公開になり得る企画")
        expect(response.body).not_to include("企画コミュニティ")
        section = doc.at_css("#top-projects")
        expect(section.text).to include("プロジェクトはログインすると閲覧できます。")
        expect(section.at_css(%(a[href="#{new_business_customer_session_path}"]))).to be_present
        expect(section.at_css(%(a[href="#{new_business_customer_registration_path}"]))).to be_present
      end
    end

    context "ログイン済み" do
      let(:viewer) { create(:customer, domain_name: "business", onboarding_done: true) }

      before { sign_in viewer }

      it "紹介用のヒーロー・スライダー・お知らせを出さず、コミュニティ・プロジェクトの2つの一覧にする" do
        get business_root_path

        expect(doc.at_css(".hero-section, .business-top-slider, .notice-section, #top-projects")).to be_nil
        expect(doc.css(".member-home__section").map { |s| s["id"] }).to eq %w[my-communities my-projects]
        expect(doc.at_css(".header_container--business")).to be_present
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

        status = doc.css("#my-projects .member-home-card").to_h do |card|
          [card.at_css(".member-home-card__title").text, card.at_css(".member-home-card__status").text]
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

        expect(doc.at_css("#my-communities .member-home-card__status").text).to eq "運営"
        expect(doc.at_css("#my-projects .member-home-card__status").text).to eq "管理"
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
