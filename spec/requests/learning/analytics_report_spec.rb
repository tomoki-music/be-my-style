require "rails_helper"

RSpec.describe "Learning analytics report", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:other_teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:student) { create(:learning_student, customer: teacher, name: "山田太郎") }
  let(:followup_student) { create(:learning_student, customer: teacher, name: "フォロー生徒") }
  let(:other_student) { create(:learning_student, customer: other_teacher, name: "佐藤花子") }

  before { sign_in teacher }

  it "顧問ダッシュボードにLearningレポートを表示すること" do
    group_key = "analytics-dashboard"
    create(:learning_assignment, customer: teacher, learning_student: student,
                                 title: "ライブ前基礎練習", status: "completed",
                                 completed_at: Time.current, assignment_group_key: group_key)
    create(:learning_assignment, customer: teacher, learning_student: student,
                                 title: "ライブ前基礎練習", status: "pending",
                                 created_at: Time.current, assignment_group_key: group_key)
    create(:learning_notification_log, customer: teacher, learning_student: student,
                                       delivery_channel: "line", status: "sent",
                                       generated_at: Time.current,
                                       reaction_received: true, reacted_at: 2.days.ago)
    create(:learning_notification_log, customer: teacher, learning_student: student,
                                       notification_type: "followup_message",
                                       delivery_channel: "line", status: "sent",
                                       generated_at: 2.days.ago,
                                       sent_at: 2.days.ago)
    create(:learning_notification_log, customer: teacher, learning_student: followup_student,
                                       notification_type: "followup_message",
                                       delivery_channel: "line", status: "sent",
                                       generated_at: 2.days.ago,
                                       sent_at: 2.days.ago)
    create(:learning_progress_log, customer: teacher, learning_student: student,
                                   practiced_on: Date.current)

    get learning_teacher_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("今週のLearningレポート")
    expect(response.body).to include("課題提出率")
    expect(response.body).to include("LINE反応率")
    expect(response.body).to include("練習記録")
    expect(response.body).to include("未提出")
    expect(response.body).to include("7日以上未反応")
    expect(response.body).to include("生徒別の状況")
    expect(response.body).to include("山田太郎")
    expect(response.body).to include("課題別の完了率")
    expect(response.body).to include("ライブ前基礎練習")
    expect(response.body).to include("最終フォロー送信：2日前")
    expect(response.body).to include("50%")
  end

  it "他顧問のデータを含めないこと" do
    create(:learning_assignment, customer: other_teacher, learning_student: other_student,
                                 title: "他校課題", status: "completed",
                                 completed_at: Time.current)
    create(:learning_notification_log, customer: other_teacher, learning_student: other_student,
                                       delivery_channel: "line", status: "sent",
                                       generated_at: Time.current,
                                       reaction_received: true, reacted_at: Time.current)

    get learning_teacher_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("今週のLearningレポート")
    expect(response.body).not_to include("他校課題")
    expect(response.body).not_to include("佐藤花子")
  end

  it "データなしでも画面が落ちないこと" do
    get learning_teacher_dashboard_path(period: "30days")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("直近30日のLearningレポート")
    expect(response.body).to include("生徒データはまだありません")
    expect(response.body).to include("課題データはまだありません")
  end
end
