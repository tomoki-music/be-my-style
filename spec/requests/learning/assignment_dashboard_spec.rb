require "rails_helper"

RSpec.describe "Learning assignment dashboard", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }

  before { sign_in teacher }

  it "今週の課題状況に提出率と期限超過件数を表示すること" do
    group_key = "phase23-dashboard"
    create(:learning_assignment, customer: teacher, status: "completed", completed_at: 1.hour.ago, assignment_group_key: group_key)
    create(:learning_assignment, customer: teacher, status: "pending", due_on: Date.current - 1.day, assignment_group_key: group_key)

    get learning_teacher_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("今週の課題状況")
    expect(response.body).to include("50%")
    expect(response.body).to include("期限超過")
    expect(response.body).to include("1人")
  end
end
