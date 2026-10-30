require "rails_helper"

# ビジネス投稿(Post)の一覧はタイムラインに統一した。旧一覧(/business/posts)は条件ごと転送する。
RSpec.describe "Business::Posts#timeline", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:viewer) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:followed) { create(:customer, domain_name: "business", onboarding_done: true, name: "フォロー先") }
  let(:mate) { create(:customer, domain_name: "business", onboarding_done: true, name: "同じコミュニティ") }
  let(:stranger) { create(:customer, domain_name: "business", onboarding_done: true, name: "知らない人") }
  let(:community) { create(:community, owner: mate, domain: business_domain) }

  let!(:followed_post) { Post.create!(customer: followed, title: "フォロー先の投稿", body: "営業の学び", category: "free_post") }
  let!(:mate_post) { Post.create!(customer: mate, title: "仲間の投稿", body: "企画メモ", category: "free_post") }
  let!(:stranger_post) { Post.create!(customer: stranger, title: "全体の投稿", body: "採用の知見", category: "free_post", tag_list: ["採用"]) }
  let!(:community_post) { CommunityPost.create!(community: community, customer: mate, body: "参加者だけの会話") }

  before do
    Relationship.create!(follower: viewer, followed: followed)
    CommunityCustomer.create!(community: community, customer: viewer)
    CommunityCustomer.create!(community: community, customer: mate)
    sign_in viewer
  end

  def titles
    Nokogiri::HTML(response.body).css(".ba-post-card").map(&:text).join(" ")
  end

  it "おすすめはすべてのビジネス投稿を出し、コミュニティ内の会話は含めない" do
    get business_timeline_path

    expect(response).to have_http_status(:ok)
    expect(titles).to include("営業の学び", "企画メモ", "採用の知見")
    expect(response.body).not_to include("参加者だけの会話")
    expect(response.body).to include("ビジネス投稿は、NAKAMAにログインしている全員が見られます。")
    expect(response.body).to include(new_business_post_path)
  end

  it "反応(いいね・コメント)の多い投稿が上に並ぶ" do
    Like.create!(customer: viewer, post: stranger_post)
    Message.create!(customer: viewer, post: stranger_post, body: "参考になります")

    get business_timeline_path

    expect(titles.index("採用の知見")).to be < titles.index("企画メモ")
  end

  it "タブは誰の投稿かで絞り込む" do
    get business_timeline_path(tab: "following")
    expect(titles).to include("営業の学び")
    expect(titles).not_to include("企画メモ", "採用の知見")

    get business_timeline_path(tab: "community")
    expect(titles).to include("企画メモ")
    expect(titles).not_to include("営業の学び", "採用の知見")

    get business_timeline_path(tab: "unknown")
    expect(titles).to include("営業の学び", "企画メモ", "採用の知見")
  end

  it "キーワード・タグ・投稿者で絞り込め、解除の導線を出す" do
    get business_timeline_path(keyword: "企画")
    expect(titles).to include("企画メモ")
    expect(titles).not_to include("営業の学び")

    get business_timeline_path(tag: "採用")
    expect(titles).to include("採用の知見")
    expect(titles).not_to include("企画メモ")
    expect(response.body).to include("タグ「採用」の絞り込みを解除")

    get business_timeline_path(user_id: followed.id)
    expect(titles).to include("営業の学び")
    expect(titles).not_to include("企画メモ")
    expect(response.body).to include("フォロー先さんの投稿")
  end

  it "旧一覧 /business/posts は絞り込み条件を保ったままタイムラインへ転送する" do
    get business_posts_path(tag: "採用", keyword: "知見", user_id: stranger.id, page: 1, other: "x")

    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to(business_timeline_path(keyword: "知見", page: 1, tag: "採用", user_id: stranger.id))
  end

  describe "旧一覧からの転送後に条件が実際に効く" do
    def follow_old_list(params)
      get business_posts_path(params)
      expect(response).to have_http_status(:moved_permanently)
      expect(URI(response.location).path).to eq business_timeline_path
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "検索語・タグ・投稿者がそれぞれ適用される" do
      follow_old_list(keyword: "企画")
      expect(titles).to include("企画メモ")
      expect(titles).not_to include("営業の学び", "採用の知見")

      follow_old_list(tag: "採用")
      expect(titles).to include("採用の知見")
      expect(titles).not_to include("営業の学び", "企画メモ")

      follow_old_list(user_id: followed.id)
      expect(titles).to include("営業の学び")
      expect(titles).not_to include("企画メモ", "採用の知見")
    end

    it "ページ番号が適用される(1ページ12件)" do
      12.times { |i| Post.create!(customer: stranger, title: "追加#{i}", body: "追加の投稿#{i}", category: "free_post", created_at: 1.day.ago) }

      follow_old_list(user_id: stranger.id, page: 2)
      expect(Nokogiri::HTML(response.body).css(".ba-post-card").size).to eq 1
    end

    it "存在しない投稿者を指定すると、全件ではなく該当なしになる" do
      follow_old_list(user_id: 0)
      expect(Nokogiri::HTML(response.body).css(".ba-post-card")).to be_empty
      expect(response.body).to include("条件に合う投稿はありません")
    end

    it "未ログインでは Business ログインへ。ログイン後は元の条件のままタイムラインで表示される" do
      sign_out viewer

      get business_posts_path(tag: "採用")
      expect(response).to redirect_to(new_business_customer_session_path)

      post business_customer_session_path, params: { customer: { email: viewer.email, password: "password" } }
      expect(response.location).to end_with(business_posts_path(tag: "採用"))
      follow_redirect!
      expect(response).to redirect_to(business_timeline_path(tag: "採用"))
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(titles).to include("採用の知見")
      expect(titles).not_to include("企画メモ")
    end

    it "外部 URL へは転送されず、文字列以外の値や他のパラメーターは引き継がない" do
      get "/business/posts?keyword=%2F%2Fevil.example&user_id=https%3A%2F%2Fevil.example&tag[]=x&return_to=https%3A%2F%2Fevil.example&host=evil.example"

      location = URI(response.location)
      expect(location.host).to eq "www.example.com"
      expect(location.path).to eq business_timeline_path
      expect(Rack::Utils.parse_query(location.query)).to eq("keyword" => "//evil.example", "user_id" => "https://evil.example")
    end

    it "タイムラインに配列などの値が来ても 500 にならず、その条件を無視する" do
      get "/business/timeline?keyword[]=x&tag[a]=b&user_id[]=1&page[]=2"

      expect(response).to have_http_status(:ok)
      expect(titles).to include("営業の学び", "企画メモ", "採用の知見")
    end
  end

  it "通知・メールのリンク先である投稿詳細はそのまま開け、パンくずはタイムラインへ戻る" do
    get business_post_path(stranger_post)

    expect(response).to have_http_status(:ok)
    breadcrumb = Nokogiri::HTML(response.body).at_css(".ba-breadcrumb")
    expect(breadcrumb.at_css(%(a[href="#{business_timeline_path}"])).text).to eq "タイムライン"
  end

  it "投稿の作成画面に、見える範囲の説明を出す" do
    get new_business_post_path

    expect(response.body).to include("ビジネス投稿は、NAKAMAにログインしている全員が見られます。")
    expect(response.body).to include(business_help_path(anchor: "help-visibility"))
  end

  it "自分の投稿を削除するとタイムラインへ戻る" do
    own = Post.create!(customer: viewer, title: "自分", body: "消す投稿", category: "free_post")

    expect { delete business_post_path(own) }.to change(Post, :count).by(-1)
    expect(response).to redirect_to(business_timeline_path)
  end

  it "ナビに「投稿」一覧は出さず、タイムラインと使い方を出す" do
    get business_timeline_path

    html = Nokogiri::HTML(response.body)
    labels = html.css(".ba-sidenav__list .ba-sidenav__label").map { |el| el.text.strip }
    expect(labels).to eq %w[ホーム コミュニティ プロジェクト タイムライン 通知 使い方]
    expect(html.at_css(%(.ba-sidenav a[href="#{business_posts_path}"]))).to be_nil
    expect(html.at_css(%(.ba-sidenav a[href="#{business_timeline_path}"]))["aria-current"]).to eq "page"
  end

  it "投稿の詳細・作成画面でも、ナビの現在地はタイムライン" do
    get business_post_path(stranger_post)

    html = Nokogiri::HTML(response.body)
    expect(html.at_css(%(.ba-sidenav a[href="#{business_timeline_path}"]))["aria-current"]).to eq "page"
  end

  it "未ログインではタイムラインも旧一覧も Business のログインへ" do
    sign_out viewer

    get business_timeline_path
    expect(response).to redirect_to(new_business_customer_session_path)

    get business_posts_path
    expect(response).to redirect_to(new_business_customer_session_path)
  end
end
