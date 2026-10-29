require 'rails_helper'

RSpec.describe "Public::Homes", type: :request do
  describe "GET / (root)" do
    context "未ログインの場合" do
      before { get root_path }

      it "200 OKでゲスト向けLPを表示すること" do
        expect(response.status).to eq 200
      end

      it "「音楽で、世界とつながる。」がヒーローの主役として表示されること" do
        expect(response.body).to include("音楽で、")
        expect(response.body).to include("世界とつながる。")
      end

      it "新規登録CTAが /customers/sign_up を指すこと" do
        expect(response.body).to include(%(href="#{new_customer_registration_path}"))
      end

      it "「AI歌唱診断を試す」CTAが新規登録画面(singingドメイン)を指すこと" do
        expect(response.body).to include(%(href="#{new_singing_customer_registration_path}"))
        expect(new_singing_customer_registration_path).to eq("/singing/sign_up")
      end

      it "「AI歌唱診断を試す」CTAが診断作成画面やログイン画面へ直接遷移しないこと" do
        doc = Nokogiri::HTML(response.body)
        ghost_ctas = doc.css(".glp-btn--ghost")
        expect(ghost_ctas).not_to be_empty
        ghost_ctas.each do |link|
          expect(link["href"]).not_to eq(new_singing_diagnosis_path)
          expect(link["href"]).not_to eq(new_customer_session_path)
        end
      end

      it "ヘッダーに既存会員向けログインボタンが表示され、ログイン画面(new_customer_session_path)へ遷移すること" do
        doc = Nokogiri::HTML(response.body)
        login_link = doc.at_css(".glp-nav-login")
        expect(login_link).to be_present
        expect(login_link["href"]).to eq(new_customer_session_path)
      end

      it "ファーストビュー(Hero)にも既存会員向けログイン導線が表示され、ログイン画面(new_customer_session_path)へ遷移すること" do
        doc = Nokogiri::HTML(response.body)
        hero_login_link = doc.at_css(".glp-hero-login-link")
        expect(hero_login_link).to be_present
        expect(hero_login_link["href"]).to eq(new_customer_session_path)
        expect(hero_login_link.text).to include("ログインはこちら")
      end

      it "フッターのコミュニティリンクがコミュニティ一覧(public_communities_path)を指すこと" do
        expect(response.body).to include(%(href="#{public_communities_path}"))
      end

      it "フッターのイベントリンクがイベント一覧(public_events_path)を指すこと" do
        expect(response.body).to include(%(href="#{public_events_path}"))
      end

      it "オフラインイベントの開催地域(埼玉中心・一部東京)とオンライン全国対応が明記されていること" do
        expect(response.body).to include("埼玉県を中心に開催")
        expect(response.body).to include("東京都内で開催する場合があります")
        expect(response.body).to include("全国")
      end

      it "感情的な中核メッセージ(一人では出会えなかった仲間と、音楽と、未来へ)が表示されること" do
        expect(response.body).to include("一人では出会えなかった")
        expect(response.body).to include("仲間と、音楽と、未来へ。")
      end

      it "AIが主役に戻っていないこと(ヒーローで巨大なAI表示がなく、Journeyでも手段として扱われること)" do
        expect(response.body).not_to include(%(class="glp-score-num"))
        expect(response.body).to include("AIは、自分を知るための手段のひとつ")
      end

      it "Journeyが歌う・演奏するから始まり、AI診断を手段として2番目に扱う順序で表示されること" do
        idx_step1 = response.body.index("好きな音楽を、今の自分のまま楽しむことから。")
        idx_step2 = response.body.index("AI歌唱診断などを通じて、自分の特徴や成長のきっかけを知る。")
        idx_step3 = response.body.index("コミュニティで、同じ音楽を楽しむ人とつながる。")
        idx_step4 = response.body.index("オンライン交流やオフラインイベントへ参加する。")
        idx_step5 = response.body.index("挑戦・成長・応援が、日常に広がっていく。")
        [idx_step1, idx_step2, idx_step3, idx_step4, idx_step5].each { |idx| expect(idx).not_to be_nil }
        expect([idx_step1, idx_step2, idx_step3, idx_step4, idx_step5]).to eq([idx_step1, idx_step2, idx_step3, idx_step4, idx_step5].sort)
      end

      it "利用料金(基本無料・イベント別途参加費・有料オプション任意)が明記されていること" do
        expect(response.body).to include("基本利用は無料")
        expect(response.body).to include("イベントごとに別途参加費")
        expect(response.body).to include("有料オプションへの加入は任意")
      end

      it "FAQに料金に関する質問と回答が含まれること" do
        expect(response.body).to include("利用料金はかかりますか？")
        expect(response.body).to include("基本機能は無料でご利用いただけます")
      end
    end

    context "ログイン済みの場合" do
      let!(:customer) { create(:customer, :customer_with_parts) }

      before do
        sign_in customer
        get root_path
      end

      it "本文はコミュニティ・プロジェクトの2つの一覧だけで、紹介用の画像・キャッチコピーを出さないこと" do
        doc = Nokogiri::HTML(response.body)

        expect(response.status).to eq 200
        expect(doc.css(".member-home__section").map { |s| s["id"] }).to eq %w[my-communities my-projects]
        expect(doc.css(".member-home__title").map { |t| t.text.squish }).to eq %w[コミュニティ プロジェクト]
        expect(response.body).not_to include("世界とつながる。")
        expect(response.body).not_to include("public-top2")
        expect(doc.at_css(".slider, .parallax, .top-cta, .owners-container")).to be_nil
        expect(response.body).not_to include("BeMyStyleへのご意見・ご相談はこちら")
      end

      it "共通ヘッダーは維持し、ご意見BOX・ログアウトはヘッダーから使えること" do
        doc = Nokogiri::HTML(response.body)

        expect(doc.at_css(".customer-menu-pc")).to be_present
        expect(doc.css(%(a[href="#{new_public_customer_feedback_path}"]))).not_to be_empty
        expect(doc.css(%(form[action="#{destroy_customer_session_path}"]))).not_to be_empty
      end

      it "0件では空状態と、既存のコミュニティ一覧への導線を出すこと" do
        doc = Nokogiri::HTML(response.body)
        communities = doc.at_css("#my-communities")
        projects = doc.at_css("#my-projects")

        expect(communities.text).to include("参加しているコミュニティはまだありません。")
        expect(communities.at_css(%(a[href="#{public_communities_path}"]))).to be_present
        expect(projects.text).to include("プロジェクトは Business（NAKAMA）のコミュニティで利用できる機能です。")
        expect(projects.at_css(%(a[href="#{business_join_path}"]))).to be_present
        expect(doc.css(".member-home-card")).to be_empty
      end

      it "Business 未登録でも、プロジェクト欄の導線から既存の Business 利用開始画面を開けること" do
        Domain.find_or_create_by!(name: "business")
        get business_join_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "未ログインの場合はご意見・ご相談BOX導線を表示しないこと" do
      before { get root_path }

      it "ゲスト向けTOPに補助導線が出ないこと" do
        expect(response.body).not_to include("BeMyStyleへのご意見・ご相談はこちら")
      end

      it "ログイン後ホームの一覧を出さないこと" do
        expect(response.body).not_to include("member-home")
      end
    end
  end

  describe "GET / (ログイン後ホームの一覧)" do
    let(:music_domain) { Domain.find_or_create_by!(name: "music") }
    let(:business_domain) { Domain.find_or_create_by!(name: "business") }
    let(:other) { create(:customer) }
    let(:customer) { create(:customer).tap { |c| CustomerDomain.create!(customer: c, domain: business_domain) } }

    before { sign_in customer }

    def doc
      Nokogiri::HTML(response.body)
    end

    def card_titles(section_id)
      doc.css("##{section_id} .member-home-card__title").map(&:text)
    end

    it "音楽コミュニティは詳細とイベント一覧(従来の導線)へ、Businessは詳細へ進めること" do
      music = create(:community, name: "音楽サークル", owner: other, domain: music_domain)
      business = create(:community, name: "企画の会", owner: other, domain: business_domain)
      CommunityCustomer.create!(community: music, customer: customer)
      CommunityCustomer.create!(community: business, customer: customer)

      get root_path

      cards = doc.css("#my-communities .member-home-card").to_h { |card| [card.at_css(".member-home-card__title").text, card] }
      expect(cards.keys).to contain_exactly("音楽サークル", "企画の会")
      expect(cards["音楽サークル"].at_css(".member-home-card__kind").text).to eq "音楽"
      expect(cards["音楽サークル"].at_css(".member-home-card__status").text).to eq "参加中"
      expect(cards["音楽サークル"].at_css(%(a[href="#{public_community_path(music)}"]))).to be_present
      expect(cards["音楽サークル"].at_css(%(a[href="#{public_events_path(community_id: music.id, status: "upcoming")}"]))).to be_present
      expect(cards["企画の会"].at_css(".member-home-card__kind").text).to eq "Business"
      expect(cards["企画の会"].at_css(%(a[href="#{business_community_path(business)}"]))).to be_present
      expect(cards["企画の会"].text).not_to include("イベントを見る")
    end

    it "申請中は状態だけを出し、紹介文などの中身を出さないこと" do
      pending = create(:community, name: "申請先", introduction: "参加者向けの紹介文", owner: other, domain: business_domain)
      Permit.create!(community: pending, customer: customer)

      get root_path

      card = doc.at_css("#my-communities .member-home-card")
      expect(card.at_css(".member-home-card__status").text).to eq "承認待ち"
      expect(card.text).not_to include("参加者向けの紹介文")
    end

    it "権限の無いコミュニティ・プロジェクトは名前も件数も出さないこと" do
      hidden = create(:community, name: "見えない会", owner: other, domain: business_domain)
      Project.create!(community: hidden, customer: other, title: "見えない企画")
      joined = create(:community, name: "参加の会", owner: other, domain: business_domain)
      CommunityCustomer.create!(community: joined, customer: customer)
      Project.create!(community: joined, customer: other, title: "未参加の企画")

      get root_path

      expect(response.body).not_to include("見えない会")
      expect(response.body).not_to include("見えない企画")
      expect(response.body).not_to include("未参加の企画")
      expect(doc.at_css("#my-communities .member-home__count").text).to eq "1件"
      expect(doc.at_css("#my-projects .member-home__count")).to be_nil
      expect(doc.at_css("#my-projects").text).to include("参加しているプロジェクトはまだありません。")
    end

    it "未参加のコミュニティ・プロジェクトへは、既存の一覧から公開範囲どおりに参加申請へ進めること" do
      music = create(:community, name: "未参加の音楽サークル", owner: other, domain: music_domain)
      business = create(:community, name: "未参加の企画の会", owner: other, domain: business_domain)
      hidden_project = Project.create!(community: business, customer: other, title: "未参加の会の企画")

      get root_path
      expect(doc.at_css(%(#my-communities a[href="#{public_communities_path}"]))).to be_present
      expect(doc.at_css(%(#my-communities a[href="#{business_communities_path}"]))).to be_present
      expect(doc.at_css(%(#my-projects a[href="#{business_projects_path}"]))).to be_present
      expect(doc.at_css(%(#my-projects a[href="#{business_communities_path}"]))).to be_present

      get public_community_path(music)
      expect(response).to have_http_status(:ok)
      get business_community_path(business)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("未参加の会の企画")

      # 未参加コミュニティのプロジェクトは、従来どおりプロジェクト一覧にも出ず詳細も開けない。
      get business_projects_path
      expect(response.body).not_to include("未参加の会の企画")
      get business_project_path(hidden_project)
      expect(response).to redirect_to(business_community_path(business))

      post business_community_permit_path(business)
      expect(Permit.where(community: business, customer: customer)).to exist
      get root_path
      expect(doc.at_css("#my-communities .member-home-card__status").text).to eq "承認待ち"
    end

    it "プロジェクトは名前・コミュニティ名・状態を出し、詳細へ直接進めること" do
      community = create(:community, name: "企画の会", owner: other, domain: business_domain)
      CommunityCustomer.create!(community: community, customer: customer)
      project = Project.create!(community: community, customer: other, title: "サイト制作")
      ProjectMember.create!(project: project, customer: customer)

      get root_path

      card = doc.at_css("#my-projects .member-home-card")
      expect(card.at_css(".member-home-card__title").text).to eq "サイト制作"
      expect(card.at_css(".member-home-card__community").text.squish).to eq "企画の会"
      expect(card.at_css(".member-home-card__status").text).to eq "参加中"
      expect(card.at_css(%(a[href="#{business_project_path(project)}"]))).to be_present

      get business_project_path(project)
      expect(response).to have_http_status(:ok)
    end

    it "カード内のリンクを入れ子にしないこと" do
      community = create(:community, owner: other, domain: music_domain)
      CommunityCustomer.create!(community: community, customer: customer)

      get root_path

      expect(doc.css("a a, a button, button a")).to be_empty
      expect(doc.css(".member-home-card > a")).to be_empty
    end

    it "一覧ごとにページ番号を分け、片方をめくってももう片方のページが変わらないこと" do
      community = create(:community, name: "企画の会", owner: other, domain: business_domain)
      CommunityCustomer.create!(community: community, customer: customer)
      6.times { |i| CommunityCustomer.create!(community: create(:community, name: "c#{i}", owner: other, domain: music_domain, updated_at: (i + 1).minutes.from_now), customer: customer) }
      7.times { |i| ProjectMember.create!(project: Project.create!(community: community, customer: other, title: "p#{i}").tap { |p| p.update_columns(updated_at: i.minutes.ago) }, customer: customer) }

      get root_path(community_page: 2)

      expect(card_titles("my-communities")).to eq %w[企画の会]
      expect(card_titles("my-projects")).to eq %w[p0 p1 p2 p3 p4 p5]
      project_next = doc.at_css(%(#my-projects .pagination a[href*="project_page=2"]))
      expect(project_next["href"]).to include("community_page=2")

      get root_path(community_page: 2, project_page: 2)

      expect(card_titles("my-communities")).to eq %w[企画の会]
      expect(card_titles("my-projects")).to eq %w[p6]
    end
  end

  describe "GET /public/homes/about" do
    let!(:customer) { create(:customer, :customer_with_parts) }

    before do
      sign_in customer
      get public_homes_about_path
    end

    it "イベント参加方法を実際の画面と同じ項目名・ボタン名で案内すること" do
      doc = Nokogiri::HTML(response.body)
      guide = doc.at_css("#event-join-guide")
      expect(guide).to be_present
      expect(guide.css(".event-join-guide__step").size).to eq 4
      %w[「楽曲」 「参加確認画面へ」 「参加する」 「削除」 「みんなのリクエスト」].each do |label|
        expect(guide.text).to include(label)
      end
    end

    it "取消期限を実装と同じ「開始時刻の7日前より前」で案内すること" do
      expect(response.body).to include("イベント開始時刻の7日前より前なら")
    end

    it "はじめ方の「イベントに参加」から参加方法へ移動できること" do
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css(".step-timeline a[href='#event-join-guide']")).to be_present
    end
  end
end
