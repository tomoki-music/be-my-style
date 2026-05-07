require "rails_helper"

RSpec.describe "Singing::Users", type: :request do
  let(:singing_customer) do
    create(
      :customer,
      domain_name: "singing",
      name: "Vocal User",
      introduction: "高音を安定させる練習を続けています。",
      singing_profile_comment: "セッション歓迎です",
      url: "https://example.com/vocal"
    )
  end
  let(:other_customer) { create(:customer, domain_name: "singing", name: "Other User") }
  let(:part) { Part.create!(name: "Vo") }
  let(:genre) { Genre.create!(name: "Rock") }

  before do
    singing_customer.parts << part
    singing_customer.genres << genre
  end

  describe "GET /singing/users/:id" do
    it "プロフィールと音楽活動の情報を表示すること" do
      sign_in other_customer
      create(:singing_diagnosis, :completed, :ranking_participant, customer: singing_customer, overall_score: 91, performance_type: :vocal)
      create(:activity, customer: singing_customer, title: "ライブ前の練習", introduction: "発声を整えました")

      get singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Vocal User")
      expect(response.body).to include("セッション歓迎です")
      expect(response.body).to include("Vo")
      expect(response.body).to include("Rock")
      expect(response.body).to include("91点")
      expect(response.body).to include("ライブ前の練習")
      expect(response.body).to include("応援リアクション")
      expect(response.body).to include("応援してます！")
      expect(response.body).not_to include(singing_customer.email)
    end

    it "プロフィールの応援リアクション数と自分のリアクション状態を表示すること" do
      sign_in other_customer
      create(:singing_profile_reaction, customer: other_customer, target_customer: singing_customer, reaction_type: "cheer")
      create(:singing_profile_reaction, target_customer: singing_customer, reaction_type: "growth")

      get singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("応援してます！")
      expect(response.body).to include("成長ナイス！")
      expect(response.body).to include("activity-reaction-btn--active")
    end

    it "未ログインでもプロフィールを閲覧でき、リアクションボタンは押せないこと" do
      get singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Vocal User")
      expect(response.body).to include("応援リアクション")
      expect(response.body).to include("disabled")
    end

    it "本人のプロフィールには編集ボタンを表示すること" do
      sign_in singing_customer

      get singing_user_path(singing_customer)

      expect(response.body).to include("プロフィールを編集")
      expect(response.body).to include(%(href="#{edit_singing_user_path(singing_customer)}"))
    end

    it "ヘッダーにはプロフィールのみを表示し、プロフィール編集メニューは表示しないこと" do
      sign_in singing_customer

      get singing_user_path(singing_customer)

      expect(response.body).to include(%(href="#{singing_user_path(singing_customer)}"))
      expect(response.body).to include("プロフィール")
      expect(response.body).not_to include("プロフィール編集")
    end

    it "他人のプロフィールには表示ユーザーを編集するボタンを表示しないこと" do
      sign_in other_customer

      get singing_user_path(singing_customer)

      expect(response.body).not_to include("プロフィールを編集")
      expect(response.body).not_to include(%(href="#{edit_singing_user_path(singing_customer)}"))
    end

    it "危険なURLをプロフィールリンクとして表示しないこと" do
      sign_in other_customer
      singing_customer.update!(url: "javascript:alert(1)")

      get singing_user_path(singing_customer)

      expect(response.body).not_to include("javascript:alert")
    end

    it "Markdown記法をHTMLとして表示すること" do
      sign_in other_customer
      singing_customer.update!(
        introduction: "## 練習メモ\n\n- 高音練習\n- リズム練習\n\n**太字の目標**\n\n[参考リンク](https://example.com)"
      )

      get singing_user_path(singing_customer)

      story_html = Nokogiri::HTML(response.body).at_css(".singing-profile__story").to_html
      expect(story_html).to include("<h2>練習メモ</h2>")
      expect(story_html).to include("<li>高音練習</li>")
      expect(story_html).to include("<strong>太字の目標</strong>")
      expect(story_html).to include(%(href="https://example.com"))
    end

    it "Markdown内の危険なHTMLとjavascriptリンクを無害化すること" do
      sign_in other_customer
      singing_customer.update!(
        introduction: "<script>alert('xss')</script>\n\n[危険リンク](javascript:alert('xss'))"
      )

      get singing_user_path(singing_customer)

      story_html = Nokogiri::HTML(response.body).at_css(".singing-profile__story").to_html
      expect(story_html).not_to include("<script")
      expect(story_html).not_to include("javascript:")
    end

    it "獲得バッジを表示すること" do
      sign_in other_customer
      create_list(:singing_diagnosis, 3, :completed, :ranking_participant, customer: singing_customer, overall_score: 82)

      get singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("獲得した称号")
      expect(response.body).to include("3回診断達成")
      expect(response.body).to include("初診断")
    end

    it "バッジがないユーザーでもプロフィールが表示できること" do
      sign_in singing_customer

      get singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("最初の診断が完了すると、ここに称号が表示されます。")
      expect(response.body).to include("まだシーズン実績はありません")
      expect(response.body).to include("診断に挑戦する")
    end

    it "獲得した SingingBadge をシーズンバッジセクションに表示すること" do
      sign_in other_customer
      season = create(
        :singing_ranking_season,
        name: "2026年4月シーズン",
        status: "closed",
        starts_on: Date.new(2026, 4, 1),
        ends_on: Date.new(2026, 4, 30)
      )
      create(
        :singing_badge,
        customer: singing_customer,
        singing_ranking_season: season,
        badge_type: "season_1st",
        awarded_at: 3.days.ago
      )

      get singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("シーズンバッジ")
      expect(response.body).to include("今月の王者")
      expect(response.body).to include("🥇")
      expect(response.body).to include("2026年4月シーズン")
      expect(response.body).to include("NEW")
    end

    it "バッジが7日より古い場合 NEW を表示しないこと" do
      sign_in other_customer
      season = create(
        :singing_ranking_season,
        name: "2026年3月シーズン",
        status: "closed",
        starts_on: Date.new(2026, 3, 1),
        ends_on: Date.new(2026, 3, 31)
      )
      create(
        :singing_badge,
        customer: singing_customer,
        singing_ranking_season: season,
        badge_type: "rapid_growth",
        awarded_at: 10.days.ago
      )

      get singing_user_path(singing_customer)

      expect(response.body).to include("急成長シンガー")
      expect(response.body).not_to include("NEW")
    end

    it "バッジが6件を超える場合に「他X件」を表示すること" do
      sign_in other_customer
      season_a = create(
        :singing_ranking_season,
        name: "2026年4月シーズン",
        status: "closed",
        starts_on: Date.new(2026, 4, 1),
        ends_on: Date.new(2026, 4, 30)
      )
      season_b = create(
        :singing_ranking_season,
        name: "2026年3月シーズン",
        status: "closed",
        starts_on: Date.new(2026, 3, 1),
        ends_on: Date.new(2026, 3, 31)
      )
      SingingBadge::BADGE_TYPES.each do |badge_type|
        create(:singing_badge, customer: singing_customer, singing_ranking_season: season_a,
                               badge_type: badge_type, awarded_at: 30.days.ago)
      end
      create(:singing_badge, customer: singing_customer, singing_ranking_season: season_b,
                             badge_type: "season_1st", awarded_at: 60.days.ago)

      get singing_user_path(singing_customer)

      expect(response.body).to include("他")
      expect(response.body).to include("件のバッジを獲得しています。")
    end

    it "バッジがないユーザーのプロフィールでバッジセクションの空状態を表示すること" do
      sign_in other_customer

      get singing_user_path(singing_customer)

      expect(response.body).to include("シーズンバッジ")
      expect(response.body).to include("バッジはまだありません。")
    end

    it "最新シーズン実績と非Premium向け案内を表示すること" do
      sign_in other_customer
      season = create(:singing_ranking_season, name: "2026年5月シーズン")
      create(
        :singing_season_ranking_entry,
        singing_ranking_season: season,
        customer: singing_customer,
        category: "pitch",
        rank: 1,
        score: 92,
        title: "Pitchリーダー",
        badge_key: "monthly_pitch_top_1"
      )

      get singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("シーズン実績")
      expect(response.body).to include("2026年5月シーズン")
      expect(response.body).to include("Pitchリーダー")
      expect(response.body).to include("🎯")
      expect(response.body).to include("TOMOKIコメント付きのシーズン振り返り")
    end

    it "season_1st バッジを持つユーザーのプロフィールに「今月の王者」称号を表示すること" do
      sign_in other_customer
      season = create(
        :singing_ranking_season,
        name: "2026年4月シーズン",
        status: "closed",
        starts_on: Date.new(2026, 4, 1),
        ends_on: Date.new(2026, 4, 30)
      )
      create(
        :singing_badge,
        customer: singing_customer,
        singing_ranking_season: season,
        badge_type: "season_1st",
        awarded_at: 3.days.ago
      )

      get singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の王者")
      expect(response.body).to include("🥇")
      expect(response.body).to include("singing-profile__title-card")
    end

    it "バッジがないユーザーのプロフィールに「挑戦者」称号を表示すること" do
      sign_in other_customer

      get singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("挑戦者")
      expect(response.body).to include("🎵")
      expect(response.body).to include("singing-profile__title-card")
    end

    it "rapid_growth バッジを持つユーザーのプロフィールに「急成長シンガー」称号を表示すること" do
      sign_in other_customer
      season = create(
        :singing_ranking_season,
        name: "2026年4月シーズン",
        status: "closed",
        starts_on: Date.new(2026, 4, 1),
        ends_on: Date.new(2026, 4, 30)
      )
      create(
        :singing_badge,
        customer: singing_customer,
        singing_ranking_season: season,
        badge_type: "rapid_growth",
        awarded_at: 5.days.ago
      )

      get singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("急成長シンガー")
      expect(response.body).to include("📈")
    end

    it "ランキング順位とシーズン順位と成長実績を表示すること" do
      sign_in other_customer
      now = Time.zone.now
      create(:singing_diagnosis, :completed, :ranking_participant, customer: other_customer, overall_score: 95, diagnosed_at: now)
      create(:singing_diagnosis, :completed, customer: singing_customer, overall_score: 75, diagnosed_at: 2.days.ago, created_at: 2.days.ago)
      create(:singing_diagnosis, :completed, :ranking_participant, customer: singing_customer, overall_score: 90, diagnosed_at: now, created_at: now)

      get singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("最高スコア")
      expect(response.body).to include("90点")
      expect(response.body).to include("診断回数")
      expect(response.body).to include("2回")
      expect(response.body).to include("総合ランキング")
      expect(response.body).to include("2位")
      expect(response.body).to include("今月のシーズン")
      expect(response.body).to include("成長ランキング 1位")
      expect(response.body).to include("+15点")
    end
  end

  describe "GET /singing/users/:id/edit" do
    it "本人は編集画面を表示できること" do
      sign_in singing_customer

      get edit_singing_user_path(singing_customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("プロフィール編集")
      expect(response.body).to include("プロフィール画像")
      expect(response.body).to include("表示名")
      expect(response.body).to include("一言コメント")
      expect(response.body).to include("SNSリンク・Webサイト")
      expect(response.body).to include("自己紹介")
      expect(response.body).to include("Markdown対応")
      expect(response.body).to include("担当パート")
      expect(response.body).to include("好きなジャンル")
    end

    it "他人は編集画面に入れないこと" do
      sign_in other_customer

      get edit_singing_user_path(singing_customer)

      expect(response).to redirect_to(singing_user_path(singing_customer))
    end
  end

  describe "PATCH /singing/users/:id" do
    it "本人はプロフィールを更新できること" do
      sign_in singing_customer
      new_part = Part.create!(name: "Gt")
      new_genre = Genre.create!(name: "Jazz")

      patch singing_user_path(singing_customer), params: {
        customer: {
          name: "New Vocal",
          introduction: "ジャズにも挑戦中です。",
          singing_profile_comment: "週末セッションできます",
          url: "https://example.com/new",
          part_ids: [new_part.id],
          genre_ids: [new_genre.id]
        }
      }

      expect(response).to redirect_to(singing_user_path(singing_customer))
      singing_customer.reload
      expect(singing_customer.name).to eq("New Vocal")
      expect(singing_customer.singing_profile_comment).to eq("週末セッションできます")
      expect(singing_customer.url).to eq("https://example.com/new")
      expect(singing_customer.parts).to contain_exactly(new_part)
      expect(singing_customer.genres).to contain_exactly(new_genre)
    end

    it "他人はプロフィールを更新できないこと" do
      sign_in other_customer

      patch singing_user_path(singing_customer), params: {
        customer: {
          name: "Changed By Other"
        }
      }

      expect(response).to redirect_to(singing_user_path(singing_customer))
      expect(singing_customer.reload.name).to eq("Vocal User")
    end
  end
end
