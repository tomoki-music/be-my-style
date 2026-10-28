require "rails_helper"

# タイムライン / プロジェクトチャットの書式(Markdown)・プレビューと、危険な入力の無害化。
RSpec.describe "Business チャットの書式とプレビュー", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "新規事業", description: "説明") }
  let(:member) { create(:customer, domain_name: "business") }

  let(:dangerous) do
    <<~MD
      **太字**

      ## 大きい文字

      - 項目1
      - 項目2

      [安全なリンク](https://example.com)
      [危険なリンク](javascript:alert(1))
      <script>alert("xss")</script>
      <img src="x" onerror="alert(2)">
      <a href="https://example.com" onclick="alert(3)">生HTML</a>
    MD
  end

  before do
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: member, community: community)
    project.members << member
    sign_in member
  end

  def expect_safe_formatted(html)
    expect(html).to include("<strong>太字</strong>")
    expect(html).to include("<h2>大きい文字</h2>")
    expect(html).to match(%r{<li>項目1\s*</li>})
    expect(html).to include('href="https://example.com"')
    # 危険なリンクはリンクにならず、ただの文字として残る。
    expect(html).not_to match(/href="javascript/i)
    expect(html).not_to include("<script")
    expect(html).not_to match(/onerror|onclick/)
  end

  it "プレビューは送信後と同じ書式で表示し、危険な HTML・URL を無害化する" do
    post business_chat_previews_path, params: { content: dangerous }, as: :json

    expect(response).to have_http_status(:ok)
    expect_safe_formatted(response.parsed_body["html"])
  end

  it "送信したタイムライン投稿・チャットも同じ書式で表示し、無害化する" do
    post business_community_community_posts_path(community), params: { community_post: { body: dangerous } }
    post business_project_project_chats_path(project), params: { project_chat: { body: dangerous } }

    get business_community_path(community)
    expect_safe_formatted(Nokogiri::HTML(response.body).at_css(".timeline-body").inner_html)

    get business_project_thread_path(project, ProjectThread.default_for(project))
    expect_safe_formatted(Nokogiri::HTML(response.body).at_css(".chat-body").inner_html)
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

  it "入力欄にわかりやすい書式ボタンとプレビュー、添付の上限案内を表示する" do
    get business_project_thread_path(project, ProjectThread.default_for(project))

    %w[太字 大きい文字 箇条書き リンク プレビュー ファイルを添付 スタンプを送る].each do |label|
      expect(response.body).to include(label)
    end
    expect(response.body).to include(BusinessChatContent.limits_description)
    expect(response.body).not_to include("H2")
  end
end
