require "rails_helper"

RSpec.describe "Learning navigation", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let!(:school_group) { create(:learning_school_group, customer: teacher, name: "軽音高校") }
  let!(:student) { create(:learning_student, customer: teacher, learning_school_group: school_group, nickname: "ギターさん") }

  before { sign_in teacher }

  it "主要Learning画面を表示できること" do
    pages = [
      [learning_root_path, "ダッシュボード"],
      [learning_school_groups_path, "高校グループ"],
      [learning_students_path, "生徒一覧"],
      [learning_student_path(student), student.name],
      [learning_student_portal_path(student.public_access_token), "#{student.display_name} さんのトレーニング"],
      [learning_student_line_connection_path(student), "LINE連携"],
      [learning_notifications_path, "通知ログ"],
      [learning_training_masters_path, "トレーニングマスター"],
      [learning_progress_logs_path, "進捗ログ"]
    ]

    pages.each do |path, expected_text|
      get path

      expect(response).to have_http_status(:ok), "#{path} returned #{response.status}"
      expect(response.body).to include(expected_text), "#{path} did not include #{expected_text}"
    end
  end
end
