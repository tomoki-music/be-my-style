require "rails_helper"

# 使い方ページ(#help-delete・#help-visibility)の「誰が編集・削除できるか」を、実際のサーバー側の認可と照合する。
# 説明を変えるときはこの spec も合わせて直す。
RSpec.describe "Business 使い方の削除・編集権限とサーバー側の認可", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:operator) { create(:customer, domain_name: "business", name: "運営者") }
  let(:system_admin) { create(:customer, domain_name: "business", is_owner: :admin) }
  let(:author) { create(:customer, domain_name: "business", name: "書いた本人") }
  let(:thread_creator) { create(:customer, domain_name: "business", name: "スレッドを作った人") }
  let(:community) { create(:community, owner: operator, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: operator, title: "検証プロジェクト") }
  let(:thread) { ProjectThread.create!(project: project, customer: thread_creator, title: "話題") }
  let!(:chat) { ProjectChat.create!(project: project, project_thread: thread, customer: author, body: "本人のメッセージ") }
  let!(:business_post) { Post.create!(customer: author, title: "本人の投稿", body: "本文", category: "free_post") }

  before do
    [operator, author, thread_creator].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    [author, thread_creator].each { |customer| ProjectMember.create!(project: project, customer: customer) }
  end

  describe "ビジネス投稿" do
    [:operator, :system_admin].each do |role|
      it "#{role} でも他人の投稿を編集・削除できない" do
        sign_in public_send(role)

        patch business_post_path(business_post), params: { post: { body: "書き換え", tag_list: "" } }
        expect { delete business_post_path(business_post) }.not_to change(Post, :count)
        expect(business_post.reload.body).to eq "本文"
      end
    end

    it "投稿した本人は削除でき、コメントも一緒に消える" do
      Message.create!(post: business_post, customer: operator, body: "コメント")
      sign_in author

      expect { delete business_post_path(business_post) }.to change(Message, :count).by(-1)
      expect(Post.exists?(business_post.id)).to eq false
    end
  end

  it "ビジネス投稿へのコメント・コミュニティ内の会話には、編集・削除の操作が無い" do
    [Business::MessagesController, Business::CommunityPostsController].each do |controller|
      expect(controller.action_methods).to include("create")
      expect(controller.action_methods & %w[edit update destroy]).to be_empty, controller.name
    end
  end

  describe "スレッド内のメッセージ" do
    [:operator, :system_admin, :thread_creator].each do |role|
      it "#{role} でも他人のメッセージは削除できない" do
        sign_in public_send(role)

        expect { delete business_project_thread_project_chat_path(project, thread, chat) }.not_to change(ProjectChat, :count)
      end
    end

    it "書いた本人は削除できる" do
      sign_in author

      expect { delete business_project_thread_project_chat_path(project, thread, chat) }.to change(ProjectChat, :count).by(-1)
    end

    it "プロジェクトから外れると、本人でも削除できない(参加している間だけ)" do
      ProjectMember.where(project: project, customer: author).destroy_all
      sign_in author

      expect { delete business_project_thread_project_chat_path(project, thread, chat) }.not_to change(ProjectChat, :count)
    end
  end

  describe "スレッドそのもの" do
    it "スレッドを作った人は編集できるが、管理者でなければ削除できない" do
      sign_in thread_creator

      patch business_project_thread_path(project, thread), params: { project_thread: { title: "話題（更新）" } }
      expect(thread.reload.title).to eq "話題（更新）"
      expect { delete business_project_thread_path(project, thread) }.not_to change(ProjectThread, :count)
    end

    it "プロジェクトの管理者(運営者)は削除でき、中のメッセージも消える。全体トークは削除できない" do
      general = ProjectThread.general_for!(project)
      sign_in operator

      expect { delete business_project_thread_path(project, thread) }.to change(ProjectChat, :count).by(-1)
      expect(ProjectThread.exists?(thread.id)).to eq false
      expect { delete business_project_thread_path(project, general) }.not_to change(ProjectThread, :count)
    end
  end

  it "プロジェクト・コミュニティを削除する操作は Business の画面に無い" do
    expect(Business::ProjectsController.action_methods).not_to include("destroy")

    sign_in operator
    get edit_business_community_path(community)
    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    delete_links = html.css(%(a[data-method="delete"][href="#{business_community_path(community)}"], form[action="#{business_community_path(community)}"] input[name="_method"][value="delete"]))
    expect(delete_links).to be_empty
  end

  it "使い方ページの説明が上の認可と同じ内容になっている" do
    get business_help_path

    html = Nokogiri::HTML(response.body)
    table = html.css("#help-operator table").find { |node| node.at_css("caption").text.include?("1件ずつ") }
    rows = table.css("tbody tr").to_h do |tr|
      [tr.at_css("th").text.strip, tr.css("td").map { |td| td.text.strip }]
    end
    expect(rows["ビジネス投稿（タイムライン）"]).to eq %w[投稿した本人だけ 投稿した本人だけ]
    expect(rows["ビジネス投稿へのコメント"].first).to eq "できません"
    expect(rows["コミュニティ内の会話"]).to eq ["できません", "できません（本人・運営者とも）"]
    expect(rows["スレッド内のメッセージ"]).to eq ["できません", "書いた本人だけ（プロジェクトに参加している間）"]
    expect(html.at_css("#help-operator").text).to include("ほかの人が書いた投稿を1件ずつ編集・削除することはできません")
  end
end
