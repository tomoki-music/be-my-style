require "rails_helper"

# タイムライン / プロジェクトチャットの本文。現在の入力欄は書式なしで、本文はすべて文字として表示する。
# 書式ボタンがあった時期の投稿(markdown)と機能追加前の投稿(legacy)は、投稿当時の表示方式のまま。
RSpec.describe "Business チャットの本文(書式なし)と過去の投稿の表示", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "新規事業", description: "説明") }
  let(:member) { create(:customer, domain_name: "business") }

  let(:input) do
    <<~TEXT.chomp
      **太字にならない** と ## 見出しにならない
      <script>alert("xss")</script>
      <img src="x" onerror="alert(2)"><b>タグも文字のまま</b>
      a < b && c > d、5>3 は数式です

      空行のあとの段落。資料は https://example.com/doc?a=1&b=2 にあります。
      javascript:alert(1) はリンクにしない
    TEXT
  end

  before do
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: member, community: community)
    project.members << member
    sign_in member
  end

  def expect_plain(body_html)
    fragment = Nokogiri::HTML.fragment(body_html)
    plain = fragment.at_css(".business-chat-plain")
    expect(plain).to be_present
    # 書式・HTML として解釈されず、文字としてそのまま表示される。
    expect(plain.css("strong, em, h1, h2, h3, ul, li, script, img, b")).to be_empty
    expect(plain.text).to include("**太字にならない** と ## 見出しにならない")
    expect(plain.text).to include(%(<script>alert("xss")</script>))
    expect(plain.text).to include(%(<img src="x" onerror="alert(2)"><b>タグも文字のまま</b>))
    expect(plain.text).to include("a < b && c > d、5>3 は数式です")
    # 改行は br、空行は段落の区切りになる。
    expect(plain.css("p").size).to eq 2
    expect(plain.css("p").first.css("br").size).to eq 3
    # URL だけをリンクにする(javascript: はリンクにしない)。
    links = plain.css("a")
    expect(links.map { |a| a["href"] }).to eq ["https://example.com/doc?a=1&b=2"]
    expect(links.first["rel"]).to eq "noopener noreferrer nofollow"
    expect(body_html).not_to match(/href="javascript/i)
  end

  it "新しいタイムライン投稿・スレッドの投稿は書式なし(plain)で保存し、本文と改行をそのまま保つ" do
    post business_community_community_posts_path(community), params: { community_post: { body: input } }
    post business_project_project_chats_path(project), params: { project_chat: { body: input } }

    [CommunityPost.last, ProjectChat.last].each do |record|
      expect(record).to be_content_format_plain
      expect(record.body).to eq input
    end

    get business_community_path(community)
    expect_plain(Nokogiri::HTML(response.body).at_css(".ba-post__body").inner_html)

    get business_project_thread_path(project, ProjectThread.default_for(project))
    expect_plain(Nokogiri::HTML(response.body).at_css(".ba-post__body").inner_html)
  end

  it "リクエストで書式(content_format)を指定しても、サーバー側で plain として保存する" do
    post business_community_community_posts_path(community), params: { community_post: { body: "**太字**", content_format: "markdown" } }
    post business_project_project_chats_path(project), params: { project_chat: { body: "**太字**", content_format: 1 } }

    expect(CommunityPost.last).to be_content_format_plain
    expect(ProjectChat.last).to be_content_format_plain

    get business_community_path(community)
    expect(Nokogiri::HTML(response.body).at_css(".ba-post__body strong")).to be_nil
  end

  it "URL のリンク化で属性や HTML を差し込めず、http(s) 以外はリンクにしない" do
    body = <<~TEXT.chomp
      https://example.com/a"onmouseover="alert(1)
      https://example.com/b'><script>alert(2)</script>
      https://example.com/c<img src=x onerror=alert(3)>
      javascript:alert(4) data:text/html,<b>x</b> vbscript:msgbox(5) ftp://example.com/file
      ｈｔｔｐｓ://全角は対象外
    TEXT
    post business_community_community_posts_path(community), params: { community_post: { body: body } }

    get business_community_path(community)
    plain = Nokogiri::HTML(response.body).at_css(".ba-post__body .business-chat-plain")

    expect(plain.css("a").map { |a| a["href"] }).to eq %w[https://example.com/a https://example.com/b https://example.com/c]
    plain.css("a").each do |link|
      expect(link.attributes.keys).to match_array %w[href target rel]
    end
    expect(plain.css("script, img, b")).to be_empty
    expect(plain.text).to include(%("onmouseover="alert(1)))
    expect(plain.text).to include("<script>alert(2)</script>")
    expect(plain.text).to include("javascript:alert(4) data:text/html,<b>x</b> vbscript:msgbox(5) ftp://example.com/file")
    expect(response.body).not_to match(/href="(javascript|data|vbscript|ftp):/i)
  end

  it "書式ボタンがあった時期の投稿は、これまでどおり書式付きで表示し、危険な HTML は無害化する" do
    body = "**太字**\n\n## 大きい文字\n\n- 項目1\n\n<script>alert(1)</script>"
    CommunityPost.create!(community: community, customer: owner, body: body, content_format: :markdown, stamp_type: "thanks")
    ProjectChat.create!(project: project, customer: owner, body: body, content_format: :markdown)

    get business_community_path(community)
    timeline = Nokogiri::HTML(response.body).at_css(".ba-post__body")
    expect(timeline.at_css(".business-chat-markdown strong").text).to eq "太字"
    expect(timeline.at_css(".business-chat-markdown h2").text).to eq "大きい文字"
    expect(timeline.at_css("script")).to be_nil
    expect(timeline.at_css(".business-chat-stamp img[alt='ありがとう']")).to be_present

    get business_project_thread_path(project, ProjectThread.default_for(project))
    chat = Nokogiri::HTML(response.body).at_css(".ba-post__body")
    expect(chat.at_css(".business-chat-markdown li").text.strip).to eq "項目1"
    expect(chat.at_css("script")).to be_nil
  end

  it "機能追加前のメッセージは従来どおり表示する" do
    CommunityPost.create!(community: community, customer: owner, body: "# 旧タイムライン見出し\n本文")
    ProjectChat.create!(project: project, customer: owner, body: "**そのまま**\n改行あり")

    get business_community_path(community)
    expect(response.body).to include("<h1>旧タイムライン見出し</h1>")

    get business_project_thread_path(project, ProjectThread.default_for(project))
    # 旧チャットはプレーンテキスト表示(simple_format)のまま。
    expect(response.body).to include("**そのまま**\n<br />改行あり")
  end

  it "入力欄には書式ボタン・プレビューを出さず、本文・添付・スタンプだけを出す" do
    [business_project_thread_path(project, ProjectThread.default_for(project)), business_community_path(community)].each do |path|
      get path
      composer = Nokogiri::HTML(response.body).at_css(".business-composer")

      expect(composer.at_css("textarea.business-composer__textarea")).to be_present
      expect(composer.at_css("[role='toolbar'], [data-format], [data-composer-tab], .business-composer__preview")).to be_nil
      %w[太字 大きい文字 箇条書き プレビュー].each { |label| expect(composer.text).not_to include(label) }
      expect(composer.text).to include("ファイルを添付")
      expect(composer.text).to include(BusinessChatContent.limits_description)
      expect(response.body).to include("スタンプを送る")
    end
  end
end
