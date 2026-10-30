require "rails_helper"

# プロジェクトの「テーマ」(1行・任意・100文字以内)の保存と表示、取りやめた「目標」「締切」を受け付けないこと。
RSpec.describe "Business プロジェクトのテーマ", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "既存プロジェクト", description: "説明") }

  before do
    CommunityCustomer.create!(community: community, customer: owner)
    sign_in owner
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def create_params(**attrs)
    { project: { community_id: community.id, title: "新しい企画", description: "説明", join_approval_mode: "manual" }.merge(attrs) }
  end

  describe "作成・編集フォーム" do
    it "テーマ(任意・最大100文字)の入力欄があり、目標・締切の入力欄は無い" do
      get new_business_project_path(community_id: community.id)

      field = doc.at_css("input#project_theme")
      expect(field["maxlength"]).to eq "100"
      expect(doc.at_css(%(label[for="project_theme"])).text).to include("テーマ", "任意")
      expect(doc.at_css("#project-theme-help").text).to include("地域のお店の魅力発信", "AIを使った仕事の改善", "100文字以内")
      expect(doc.at_css("#project_goal, #project_deadline")).to be_nil
      expect(response.body).not_to include("目標", "締切")

      get edit_business_project_path(project)
      expect(doc.at_css("input#project_theme")).to be_present
      expect(doc.at_css("#project_goal, #project_deadline")).to be_nil
    end
  end

  describe "保存" do
    it "作成時にテーマを保存し、前後の空白と改行を整える" do
      post business_projects_path, params: create_params(theme: "  地域のお店の\n魅力発信  ")

      expect(Project.last.theme).to eq "地域のお店の 魅力発信"
    end

    it "未入力・空白だけなら未設定(NULL)で保存できる" do
      post business_projects_path, params: create_params(theme: "   ")

      expect(response).to have_http_status(:redirect)
      expect(Project.last.theme).to be_nil
    end

    it "100文字ちょうどは保存でき、101文字はエラーで入力内容を保持したまま再表示する" do
      post business_projects_path, params: create_params(theme: "あ" * 100)
      expect(Project.last.theme.length).to eq 100

      expect do
        post business_projects_path, params: create_params(title: "長すぎる企画", theme: "い" * 101)
      end.not_to change(Project, :count)
      expect(doc.at_css(".ba-errors").text).to include("テーマは100文字以内で入力してください")
      expect(doc.at_css("input#project_theme")["value"]).to eq "い" * 101
      expect(doc.at_css("input#project_title")["value"]).to eq "長すぎる企画"
    end

    it "編集でテーマを更新・削除でき、101文字では更新しない" do
      patch business_project_path(project), params: { project: { theme: "AIを使った仕事の改善" } }
      expect(project.reload.theme).to eq "AIを使った仕事の改善"

      patch business_project_path(project), params: { project: { title: "改名", theme: "う" * 101 } }
      expect(project.reload.theme).to eq "AIを使った仕事の改善"
      expect(project.title).to eq "既存プロジェクト"
      expect(doc.at_css("input#project_theme")["value"]).to eq "う" * 101
      expect(doc.at_css("input#project_title")["value"]).to eq "改名"

      patch business_project_path(project), params: { project: { theme: "" } }
      expect(project.reload.theme).to be_nil
    end

    it "目標・締切を直接送っても、作成・更新とも保存しない(既存の値は残る)" do
      post business_projects_path, params: create_params(goal: "送られた目標", deadline: "2030-01-01")
      created = Project.last
      expect([created.goal, created.deadline]).to eq [nil, nil]

      project.update_columns(goal: "既存の目標", deadline: Time.zone.parse("2026-01-01 00:00"))
      patch business_project_path(project), params: { project: { goal: "書き換え", deadline: "2030-12-31", theme: "新テーマ" } }

      project.reload
      expect(project.theme).to eq "新テーマ"
      expect(project.goal).to eq "既存の目標"
      expect(project.deadline).to eq Time.zone.parse("2026-01-01 00:00")
    end
  end

  describe "詳細画面" do
    it "テーマがあれば表示し、目標・締切は(既存データがあっても)表示しない" do
      project.update_columns(theme: "地域のお店の魅力発信", goal: "既存の目標", deadline: 1.day.ago)

      get business_project_path(project)

      expect(doc.at_css(".ba-theme__label").text.strip).to eq "テーマ"
      expect(doc.at_css(".ba-theme__text").text).to eq "地域のお店の魅力発信"
      expect(response.body).not_to include("既存の目標", "締切", "募集終了")
    end

    it "テーマ未設定の既存プロジェクトは、テーマ欄そのものを出さない" do
      get business_project_path(project)

      expect(response).to have_http_status(:ok)
      expect(doc.at_css(".ba-theme")).to be_nil
      expect(response.body).not_to include("テーマ：", "未設定")
    end
  end
end
