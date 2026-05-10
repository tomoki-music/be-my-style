require "rails_helper"

RSpec.describe "Learning assignment index", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }

  before { sign_in teacher }

  describe "GET /learning/assignments" do
    it "課題一覧に提出率と提出数を表示すること" do
      group_key = "phase23-index-group"
      create(:learning_assignment, customer: teacher, title: "ライブ前基礎練習", status: "completed", assignment_group_key: group_key, completed_at: 1.hour.ago)
      create(:learning_assignment, customer: teacher, title: "ライブ前基礎練習", status: "pending", assignment_group_key: group_key)
      create(:learning_assignment, customer: teacher, title: "ライブ前基礎練習", status: "in_progress", assignment_group_key: group_key)

      get learning_assignments_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ライブ前基礎練習")
      expect(response.body).to include("33%")
      expect(response.body).to include("1人")
      expect(response.body).to include("2人")
    end

    it "他顧問の課題は表示しないこと" do
      other_teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
      create(:learning_assignment, customer: other_teacher, title: "他校の課題")

      get learning_assignments_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("他校の課題")
    end

    it "期限超過人数を表示すること" do
      group_key = "phase23-overdue-index"
      create(:learning_assignment, customer: teacher, title: "期限チェック", status: "pending", due_on: Date.current - 1.day, assignment_group_key: group_key)
      create(:learning_assignment, customer: teacher, title: "期限チェック", status: "completed", due_on: Date.current - 1.day, assignment_group_key: group_key)

      get learning_assignments_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("期限チェック")
      expect(response.body).to include("期限超過")
    end
  end
end
