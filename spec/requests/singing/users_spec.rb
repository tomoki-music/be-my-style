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
      expect(response.body).not_to include(singing_customer.email)
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
