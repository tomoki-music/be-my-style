require "rails_helper"

# スレッド・参加申請・メンバー管理の主要画面をスマホ幅(375px)と PC 幅で開き、横にはみ出さないことを確認する。
RSpec.describe "Business スレッド・参加管理の画面幅", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, name: "とても長い名前のコミュニティ運営者さん", domain_name: "business", onboarding_done: true) }
  let(:applicant) { create(:customer, name: "申請中のとても長い名前のユーザーさん", domain_name: "business", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "Web制作コミュニティ") }
  let(:project) { Project.create!(community: community, customer: owner, title: "A社ホームページ制作プロジェクト（長いタイトルの確認用）", description: "概要" * 40) }

  before do
    CommunityCustomer.create!(community: community, customer: owner)
    thread = project.project_threads.create!(customer: owner, title: "デザイン相談スレッド" * 3, description: "配色・レイアウト" * 10)
    ProjectChat.create!(project: project, project_thread: thread, customer: owner, body: "長いメッセージ" * 30)
    create(:permit, community: community, customer: applicant)
  end

  def sign_in_via_business_form(customer)
    visit new_business_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_current_path(business_root_path, wait: 10)
  end

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  { "スマホ" => -> { use_mobile_viewport }, "PC" => -> { use_desktop_viewport } }.each do |label, viewport|
    it "#{label}: 管理者のプロジェクト・スレッド・メンバー管理画面が横にはみ出さない" do
      sign_in_via_business_form(owner)
      instance_exec(&viewport)
      thread = project.project_threads.recently_active.first

      {
        business_project_path(project) => "スレッド",
        business_project_threads_path(project) => "スレッド一覧",
        business_project_thread_path(project, thread) => thread.title,
        new_business_project_thread_path(project) => "新しいスレッド",
        members_business_project_path(project) => "メンバー管理",
        business_permits_path(community) => applicant.name
      }.each do |path, text|
        visit path
        expect(page).to have_text(text)
        expect(horizontal_overflow).to be <= 0, "#{path} が横にはみ出しています"
      end
    end

    it "#{label}: 未参加者のコミュニティ画面は概要と申請ボタンだけを表示し、はみ出さない" do
      outsider = create(:customer, domain_name: "business", onboarding_done: true)
      sign_in_via_business_form(outsider)
      instance_exec(&viewport)

      visit business_community_path(community)

      expect(page).to have_link("参加を申請する")
      expect(page).to have_text("コミュニティの参加者のみ閲覧できます")
      expect(page).not_to have_text(project.title)
      expect(horizontal_overflow).to be <= 0
    end
  end
end
