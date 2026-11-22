require "rails_helper"

# プロジェクト内スレッドの固定(ProjectThread#pinned_at)。
# 固定・解除できるのはシステム管理者と親コミュニティのオーナー本人だけで、ボタン表示と保存側が同じ判定であること、
# 一覧(ページ送り・プロジェクト画面の先頭5件を含む)で固定スレッドが新しく固定した順に先頭へ並ぶことを確かめる。
RSpec.describe "Business スレッドの固定", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", name: "オーナー本人", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "固定コミュニティ") }
  let(:admin) { create(:customer, domain_name: "business", name: "システム管理者", is_owner: :admin, onboarding_done: true) }
  let(:co_manager) { create(:customer, domain_name: "business", name: "共同運営者", onboarding_done: true) }
  let(:creator) { create(:customer, domain_name: "business", name: "プロジェクト作成者", onboarding_done: true) }
  let(:member) { create(:customer, domain_name: "business", name: "承認済みメンバー", onboarding_done: true) }
  let(:outsider) { create(:customer, domain_name: "business", name: "コミュニティ外さん", onboarding_done: true) }
  let!(:project) { Project.create!(community: community, customer: creator, title: "固定の企画", thread_creation_policy: :all_members) }
  let!(:general_thread) { project.project_threads.find_by!(general: true) }

  before do
    [owner, co_manager, creator, member].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    CommunityOwner.create!(community: community, customer: co_manager)
    ProjectMember.create!(project: project, customer: member)
  end

  # last_posted_at が days_ago 日前のスレッドを作る(通常の並びは新しく投稿があった順)。
  def create_thread(title, days_ago:)
    project.project_threads.create!(title: title, customer: member, last_posted_at: days_ago.days.ago)
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def listed_titles
    doc.css(".ba-thread-list__title").map { |node| node.text.strip }
  end

  def pinned_titles
    doc.css(".ba-thread-list__item--pinned .ba-thread-list__title").map { |node| node.text.strip }
  end

  def pin_forms(thread)
    doc.css(%(form[action="#{business_project_thread_pin_path(project, thread)}"]))
  end

  def pin(thread)
    post business_project_thread_pin_path(project, thread)
  end

  def unpin(thread)
    delete business_project_thread_pin_path(project, thread)
  end

  describe "既存スレッド" do
    it "固定なしとして扱い、従来どおり新しく投稿があった順に並ぶ" do
      old = create_thread("古い話題", days_ago: 3)
      recent = create_thread("最近の話題", days_ago: 1)
      general_thread.update!(last_posted_at: 2.days.ago)

      expect(ProjectThread.where(project: project).pluck(:pinned_at)).to all(be_nil)

      sign_in member
      get business_project_threads_path(project)
      expect(listed_titles).to eq [recent.title, general_thread.title, old.title]
      expect(doc.css(".ba-thread-pin-badge")).to be_empty
    end
  end

  describe "固定・解除" do
    let!(:old) { create_thread("古い話題", days_ago: 3) }
    let!(:recent) { create_thread("最近の話題", days_ago: 1) }

    before { general_thread.update!(last_posted_at: 2.days.ago) }

    it "オーナーが固定すると先頭に出て全員に「固定」が見え、解除すると通常の並びに戻る" do
      sign_in owner
      get business_project_threads_path(project)
      expect(pin_forms(old).size).to eq 1
      expect(pin_forms(old).first.text).to include "固定する"

      pin(old)
      expect(response).to redirect_to(business_project_thread_path(project, old))
      expect(old.reload).to be_pinned

      sign_out owner
      sign_in member
      get business_project_threads_path(project)
      expect(listed_titles).to eq [old.title, recent.title, general_thread.title]
      expect(pinned_titles).to eq [old.title]
      badge = doc.at_css(".ba-thread-list__item--pinned .ba-thread-pin-badge")
      expect(badge.text.strip).to eq "固定"
      expect(badge.at_css("i.fa-thumbtack")).to be_present

      get business_project_thread_path(project, old)
      expect(doc.at_css(".ba-thread-header .ba-thread-pin-badge").text.strip).to eq "固定"

      sign_out member
      sign_in owner
      get business_project_threads_path(project)
      expect(pin_forms(old).first.text).to include "固定を解除"
      expect(pin_forms(old).first.at_css(%(input[name="_method"][value="delete"]))).to be_present

      unpin(old)
      expect(old.reload).not_to be_pinned

      get business_project_threads_path(project)
      expect(listed_titles).to eq [recent.title, general_thread.title, old.title]
      expect(doc.css(".ba-thread-pin-badge")).to be_empty
    end

    it "一覧から操作したときは一覧へ戻る" do
      sign_in admin
      pin(old)
      expect(response).to redirect_to(business_project_thread_path(project, old))

      unpin(old)
      post business_project_thread_pin_path(project, old), headers: { "HTTP_REFERER" => business_project_threads_url(project) }
      expect(response).to redirect_to(business_project_threads_url(project))
      expect(flash[:notice]).to eq "スレッドを固定しました"
    end

    it "システム管理者も固定・解除でき、「全体トーク」も固定できる" do
      sign_in admin
      pin(general_thread)
      expect(general_thread.reload).to be_pinned
      unpin(general_thread)
      expect(general_thread.reload).not_to be_pinned
    end

    it "複数固定すると新しく固定した順に並び、その後ろに通常の順で続く。固定済みを再度固定しても順番は変わらない" do
      sign_in owner
      travel_to(3.hours.ago) { pin(old) }
      travel_to(2.hours.ago) { pin(general_thread) }
      travel_to(1.hour.ago) { pin(recent) }

      get business_project_threads_path(project)
      expect(listed_titles).to eq [recent.title, general_thread.title, old.title]

      newest = create_thread("いちばん新しい話題", days_ago: 0)
      pin(old)
      get business_project_threads_path(project)
      expect(listed_titles).to eq [recent.title, general_thread.title, old.title, newest.title]
      expect(pinned_titles).to eq [recent.title, general_thread.title, old.title]

      unpin(general_thread)
      get business_project_threads_path(project)
      expect(listed_titles).to eq [recent.title, old.title, newest.title, general_thread.title]
    end

    it "プロジェクト画面の先頭5件にも固定スレッドが優先して入る" do
      oldest = create_thread("いちばん古い話題", days_ago: 30)
      5.times { |i| create_thread("新しめの話題#{i}", days_ago: 0) }

      sign_in owner
      pin(oldest)

      sign_out owner
      sign_in member
      get business_project_path(project)
      titles = doc.css("#threads .ba-thread-list__title").map { |node| node.text.strip }
      expect(titles.size).to eq Business::ProjectsController::THREAD_PREVIEW_LIMIT
      expect(titles.first).to eq oldest.title
      expect(doc.at_css("#threads .ba-thread-list__item--pinned .ba-thread-pin-badge")).to be_present
    end
  end

  describe "ページ送り" do
    let(:per_page) { Business::ProjectThreadsController::THREADS_PER_PAGE }

    it "固定を優先した順序でページを分け、固定スレッドが重複・欠落しない" do
      threads = Array.new(per_page + 4) { |i| create_thread("話題#{format('%02d', i)}", days_ago: i + 1) }
      general_thread.update!(last_posted_at: 1.year.ago)
      # 通常の並びでは2ページ目に入る、古いスレッドを固定する。
      first_pinned = threads[-1]
      second_pinned = threads[-2]

      sign_in owner
      travel_to(2.hours.ago) { pin(first_pinned) }
      travel_to(1.hour.ago) { pin(second_pinned) }

      get business_project_threads_path(project)
      page1 = listed_titles
      expect(page1.size).to eq per_page
      expect(page1.first(2)).to eq [second_pinned.title, first_pinned.title]
      expect(doc.css(%(a[href="#{business_project_threads_path(project, page: 2)}"]))).to be_present

      get business_project_threads_path(project, page: 2)
      page2 = listed_titles
      expect(page2).not_to include(first_pinned.title, second_pinned.title)
      expect(doc.css(".ba-thread-pin-badge")).to be_empty

      unpinned_order = (threads - [first_pinned, second_pinned]).map(&:title) + [general_thread.title]
      expect(page1 + page2).to eq [second_pinned.title, first_pinned.title] + unpinned_order
    end
  end

  describe "権限" do
    let!(:thread) { create_thread("権限の話題", days_ago: 1) }

    it "固定・解除のボタンはシステム管理者とオーナー本人にだけ表示される" do
      { admin => 1, owner => 1, co_manager => 0, creator => 0, member => 0 }.each do |customer, count|
        sign_in customer
        get business_project_threads_path(project)
        expect(pin_forms(thread).size).to eq(count), "#{customer.name} の一覧"
        get business_project_thread_path(project, thread)
        expect(pin_forms(thread).size).to eq(count), "#{customer.name} の詳細"
        expect(customer.can_pin_project_thread?(thread)).to eq(count == 1)
        sign_out customer
      end
    end

    it "権限外の参加者の直接リクエストは拒否し、固定状態を変えない" do
      [co_manager, creator, member].each do |customer|
        sign_in customer
        expect { pin(thread) }.not_to(change { thread.reload.pinned_at })
        expect(response).to redirect_to(business_project_thread_path(project, thread))
        expect(flash[:alert]).to eq "スレッドを固定・解除できるのは、システム管理者とコミュニティのオーナーだけです。"
        sign_out customer
      end

      thread.update!(pinned_at: 1.hour.ago)
      [co_manager, creator, member].each do |customer|
        sign_in customer
        expect { unpin(thread) }.not_to(change { thread.reload.pinned_at })
        expect(response).to redirect_to(business_project_thread_path(project, thread))
        sign_out customer
      end
    end

    it "プロジェクトに参加していない人・ログインしていない人の直接リクエストも拒否する" do
      sign_in outsider
      expect { pin(thread) }.not_to(change { thread.reload.pinned_at })
      expect(response).to have_http_status(:redirect)
      sign_out outsider

      expect { pin(thread) }.not_to(change { thread.reload.pinned_at })
      expect(response).to have_http_status(:redirect)
    end

    it "別プロジェクトのスレッドは見つからない扱いにする" do
      other_project = Project.create!(community: community, customer: creator, title: "別の企画")
      other_thread = other_project.project_threads.create!(title: "別の話題", customer: creator)

      sign_in owner
      expect { post business_project_thread_pin_path(project, other_thread) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(other_thread.reload).not_to be_pinned
    end
  end
end
