require "rails_helper"

RSpec.describe "Business チャットのスタンプ", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:member) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "新規事業", description: "説明") }

  before do
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: member, community: community)
    project.members << member
    sign_in member
  end

  def picker
    Nokogiri::HTML(response.body).at_css(".business-stamp-picker")
  end

  def stamp_keys_in(tabpanel)
    tabpanel.css("input[type='hidden'][name$='[stamp_type]']").map { |input| input["value"] }
  end

  {
    "タイムライン" => { path: -> { business_community_path(community) }, param: "community_post" },
    "プロジェクトチャット" => { path: -> { business_project_thread_path(project, ProjectThread.default_for(project)) }, param: "project_chat" }
  }.each do |label, config|
    it "#{label}のピッカーは「シンプル」「動物」タブに全スタンプを並べ、タブの aria 属性を持つ" do
      get instance_exec(&config[:path])

      tabs = picker.css("[role='tablist'] [role='tab']")
      expect(tabs.map(&:text).map(&:strip)).to eq %w[シンプル 動物]
      expect(tabs.map { |tab| tab["aria-selected"] }).to eq %w[true false]
      expect(tabs.map { |tab| tab["tabindex"] }).to eq %w[0 -1]

      panels = picker.css("[role='tabpanel']")
      expect(panels.map { |panel| panel["aria-labelledby"] }).to eq tabs.map { |tab| tab["id"] }
      expect(tabs.map { |tab| tab["aria-controls"] }).to eq panels.map { |panel| panel["id"] }
      expect(panels.map { |panel| panel.key?("hidden") }).to eq [false, true]

      expect(stamp_keys_in(panels[0])).to eq BusinessChatContent.stamp_tabs[:simple][:definitions].keys
      expect(stamp_keys_in(panels[1])).to eq BusinessChatContent.stamp_tabs[:animal][:definitions].keys
      expect(picker.css("input[name='#{config[:param]}[stamp_type]']").size).to eq 26
      expect(picker.css("img.stamp-choice__img").map { |img| img["src"] }).to all(be_present)
      labels = picker.css("button.stamp-choice").map { |button| button["aria-label"] }
      expect(labels.uniq.size).to eq 26
      expect(labels).to include("ありがとうスタンプを送信", "ありがとう（人物）スタンプを送信", "了解！スタンプを送信")
    end
  end

  it "タイムラインで両タブの全スタンプを送信・表示できる" do
    BusinessChatContent::STAMP_TYPES.each do |key|
      expect {
        post business_community_community_posts_path(community), params: { community_post: { stamp_type: key } }
      }.to change(CommunityPost, :count).by(1), "#{key} を送信できません"
      expect(CommunityPost.last.stamp_type).to eq key
    end

    get business_community_path(community)
    shown = Nokogiri::HTML(response.body).css(".business-chat-stamp img.stamp-illustration").map { |img| img["alt"] }
    expect(shown).to match_array(BusinessChatContent::STAMP_TYPES.map { |key| Stampable::STAMP_DEFINITIONS[key][:label] })
  end

  it "プロジェクトチャットで両タブのスタンプを送信・表示できる" do
    BusinessChatContent::STAMP_TYPES.each do |key|
      expect {
        post business_project_project_chats_path(project), params: { project_chat: { stamp_type: key } }
      }.to change(ProjectChat, :count).by(1), "#{key} を送信できません"
    end

    get business_project_thread_path(project, ProjectThread.default_for(project))
    shown = Nokogiri::HTML(response.body).css(".business-chat-stamp img.stamp-illustration").map { |img| img["alt"] }
    expect(shown.size).to eq 26
  end

  it "不正なスタンプ識別子は保存せずエラーを表示する" do
    ["../../etc/passwd", "clap", "animal_unknown"].each do |key|
      expect {
        post business_community_community_posts_path(community), params: { community_post: { stamp_type: key } }
      }.not_to change(CommunityPost, :count)
      expect(flash[:alert]).to include("選択されたスタンプは利用できません")

      expect {
        post business_project_project_chats_path(project), params: { project_chat: { stamp_type: key } }
      }.not_to change(ProjectChat, :count)
    end
  end

  it "以前から送信済みの6種類のスタンプは引き続き表示される" do
    %w[thanks animal_got_it like good_job please ok].each do |key|
      CommunityPost.create!(community: community, customer: owner, stamp_type: key)
    end

    get business_community_path(community)

    expect(Nokogiri::HTML(response.body).css(".business-chat-stamp img.stamp-illustration").size).to eq 6
  end
end
